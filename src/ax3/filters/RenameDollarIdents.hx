package ax3.filters;

/**
	AS3 allows `$` in identifiers, Haxe does not, so everything declared with a
	`$` in its name (local vars, function args, catch vars, class fields) is
	renamed to a valid Haxe identifier: the `$` characters are stripped, and if
	the resulting name is already taken in the same scope (e.g. a `foo` next to
	`$foo`), a numeric suffix is appended (`foo1`, `foo2`, ...).

	Field renames are coordinated across the class hierarchy, so overrides and
	interface implementations of a `$`-named member all get the same new name.
	Fields of extern (SWC) classes are never renamed - accessing those reports
	an error instead, since we can't change the runtime name of a library field.

	This filter must run before all other filters, so they only ever see valid names.
**/
class RenameDollarIdents extends AbstractFilter {
	// would-be-conflicting rename targets that are fine in AS3 but reserved in Haxe
	static final haxeKeywords = [
		"abstract", "break", "case", "cast", "catch", "class", "continue", "default",
		"do", "dynamic", "else", "enum", "extends", "extern", "false", "final",
		"for", "function", "if", "implements", "import", "in", "inline", "interface",
		"macro", "new", "null", "operator", "overload", "override", "package",
		"private", "public", "return", "static", "switch", "this", "throw", "true",
		"try", "typedef", "untyped", "using", "var", "while"
	];

	final fieldRenames = new Map<TClassOrInterfaceDecl, Map<String,String>>();

	static inline function hasDollar(name:String):Bool {
		return name.indexOf("$") != -1;
	}

	static function makeUniqueName(oldName:String, isTaken:String->Bool):String {
		var base = StringTools.replace(oldName, "$", "");
		if (base == "" || (base.charCodeAt(0) >= "0".code && base.charCodeAt(0) <= "9".code)) {
			base = "_" + base;
		}
		var candidate = base;
		var i = 1;
		while (isTaken(candidate) || haxeKeywords.indexOf(candidate) != -1) {
			candidate = base + (i++);
		}
		return candidate;
	}

	override function processClass(c:TClassOrInterfaceDecl) {
		computeFieldRenames(c);
		var renames = fieldRenames[c];
		for (m in c.members) {
			switch m {
				case TMField(field):
					switch field.kind {
						case TFVar(v):
							var newName = renames[v.name];
							if (newName != null) v.name = newName;
						case TFFun(f):
							var newName = renames[f.name];
							if (newName != null) f.name = newName;
						case TFGetter(f) | TFSetter(f):
							var newName = renames[f.name];
							if (newName != null) f.name = newName;
					}
				case _:
			}
		}

		super.processClass(c); // this rewrites `$`-field accesses via processExpr

		// locals declared in static initializer blocks
		for (m in c.members) {
			switch m {
				case TMStaticInit(i): renameLocals([], i.expr);
				case _:
			}
		}
	}

	override function processFunction(fun:TFunction) {
		super.processFunction(fun);
		renameLocals(fun.sig.args, fun.expr);
	}

	override function processVarField(v:TVarField) {
		super.processVarField(v);
		// a field initializer can contain local functions with their own args
		if (v.init != null) renameLocals([], v.init.expr);
	}

	// locals, args and catch vars: one rename scope per function body,
	// which matches AS3's function-wide (hoisted) local scoping

	function renameLocals(args:Array<TFunctionArg>, expr:Null<TExpr>) {
		var vars:Array<TVar> = [];
		var argDecls:Array<TFunctionArg> = [];
		var taken = new Map<String,Bool>();

		function addVar(v:TVar) {
			vars.push(v);
			taken[v.name] = true;
		}
		function addArg(a:TFunctionArg) {
			argDecls.push(a);
			taken[a.name] = true;
			if (a.v != null) vars.push(a.v);
		}

		for (a in args) addArg(a);

		function collect(e:TExpr) {
			switch e.kind {
				case TEVars(_, decls): for (d in decls) addVar(d.v);
				case TELocal(_, v): addVar(v);
				case TETry(t): for (c in t.catches) addVar(c.v);
				case TELocalFunction(f): for (a in f.fun.sig.args) addArg(a);
				// renaming a local must not shadow anything referenced without qualification
				case TEField({kind: TOImplicitThis(_) | TOImplicitClass(_)}, fieldName, _): taken[fieldName] = true;
				case TEDeclRef(path, _) if (path.rest.length == 0): taken[path.first.text] = true;
				case _:
			}
			iterExpr(collect, e);
		}
		if (expr != null) collect(expr);

		var dollarNames = [];
		for (v in vars) if (hasDollar(v.name) && dollarNames.indexOf(v.name) == -1) dollarNames.push(v.name);
		for (a in argDecls) if (hasDollar(a.name) && dollarNames.indexOf(a.name) == -1) dollarNames.push(a.name);
		if (dollarNames.length == 0) return;

		var renames = new Map<String,String>();
		for (oldName in dollarNames) {
			var newName = makeUniqueName(oldName, n -> taken.exists(n));
			renames[oldName] = newName;
			taken[newName] = true;
		}

		for (v in vars) {
			var newName = renames[v.name];
			if (newName != null) v.name = newName; // TVars are shared between declaration and uses
		}
		for (a in argDecls) {
			var newName = renames[a.name];
			if (newName != null) a.name = newName;
		}
	}

	// class fields

	function getParents(c:TClassOrInterfaceDecl):Array<TClassOrInterfaceDecl> {
		var parents = [];
		switch c.kind {
			case TClass(info):
				if (info.extend != null) parents.push(info.extend.superClass);
				if (info.implement != null) for (i in info.implement.interfaces) parents.push(i.iface.decl);
			case TInterface(info):
				if (info.extend != null) for (i in info.extend.interfaces) parents.push(i.iface.decl);
		}
		return parents;
	}

	function computeFieldRenames(c:TClassOrInterfaceDecl) {
		if (fieldRenames.exists(c)) return;
		var map = new Map<String,String>();
		fieldRenames[c] = map;
		if (c.parentModule.isExtern) return; // never rename fields of library classes

		for (p in getParents(c)) computeFieldRenames(p);

		for (m in c.members) {
			switch m {
				case TMField(field):
					var name = switch field.kind {
						case TFVar(v): v.name;
						case TFFun(f): f.name;
						case TFGetter(f) | TFSetter(f): f.name;
					}
					if (!hasDollar(name) || map.exists(name)) continue;
					// overrides/implementations must get the same name as the original declaration
					var inherited = findParentRename(c, name);
					map[name] = if (inherited != null) inherited else makeUniqueName(name, n ->
						c.findFieldInHierarchy(n, null) != null || renameTargetExists(c, n)
					);
				case _:
			}
		}
	}

	function findParentRename(c:TClassOrInterfaceDecl, name:String):Null<String> {
		for (p in getParents(c)) {
			computeFieldRenames(p);
			var newName = fieldRenames[p][name];
			if (newName == null) newName = findParentRename(p, name);
			if (newName != null) return newName;
		}
		return null;
	}

	function renameTargetExists(c:TClassOrInterfaceDecl, name:String):Bool {
		var map = fieldRenames[c];
		if (map != null) {
			for (newName in map) {
				if (newName == name) return true;
			}
		}
		for (p in getParents(c)) {
			if (renameTargetExists(p, name)) return true;
		}
		return false;
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEField(obj, fieldName, fieldToken) if (hasDollar(fieldName)):
				var newName = resolveFieldRename(obj, fieldName);
				if (newName == null) {
					reportError(exprPos(e), "Cannot rename `" + fieldName + "` field access: unknown, untyped or extern receiver ($ is not allowed in Haxe identifiers)");
					e;
				} else {
					e.with(kind = TEField(obj, newName, fieldToken.with(TkIdent, newName)));
				}
			case _:
				e;
		}
	}

	function resolveFieldRename(obj:TFieldObject, fieldName:String):Null<String> {
		var cls:Null<TClassOrInterfaceDecl> = switch obj.kind {
			case TOImplicitThis(c) | TOImplicitClass(c): c;
			case TOExplicit(_, _):
				switch obj.type {
					case TTInst(c) | TTStatic(c): c;
					case _: null;
				}
		}
		if (cls == null) return null;
		// don't use findFieldInHierarchy here: declarations may already be renamed,
		// while the rename maps are keyed by the original names (they are always
		// computed before any mutation, see computeFieldRenames memoization)
		computeFieldRenames(cls);
		var newName = fieldRenames[cls][fieldName];
		if (newName == null) newName = findParentRename(cls, fieldName);
		return newName;
	}
}
