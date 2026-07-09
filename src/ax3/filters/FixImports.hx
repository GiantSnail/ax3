package ax3.filters;

import ax3.GenHaxe.canSkipTypeHint;

class FixImports extends AbstractFilter {
	var usedClasses:Null<Map<TClassOrInterfaceDecl, Bool>>;
	var seenImports:Null<Map<String, Bool>>;

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		switch e.kind {
			case TEVars(_, vars):
				for (v in vars) {
					if (v.init == null || !canSkipTypeHint(v.v.type, v.init.expr)) {
						markTypeUsed(v.v.type);
					}
				}
			case TEDeclRef(_, {kind: TDClassOrInterface(c)}):
				markClassUsed(c);
			case TENew(_, TNType(t), _):
				markTypeUsed(t.type);
			case TECast(c):
				markTypeUsed(c.type);
			case TEVector(_, t):
				markTypeUsed(t);
			case TEHaxeRetype(_):
				markTypeUsed(e.type);
			case _:
		}
		return e;
	}

	override function processModule(mod:TModule) {
		usedClasses = new Map();
		seenImports = new Map();
		processDecl(mod.pack.decl);
		for (decl in mod.privateDecls) {
			processDecl(decl);
		}
		processImports(mod);
		usedClasses = null;
		seenImports = null;
	}

	override function processClass(c:TClassOrInterfaceDecl) {
		super.processClass(c);
		switch c.kind {
			case TInterface(info):
				if (info.extend != null) {
					for (i in info.extend.interfaces) {
						markClassUsed(i.iface.decl);
					}
				}
			case TClass(info):
				if (info.extend != null) {
					markClassUsed(info.extend.superClass);
				}
				if (info.implement != null) {
					for (i in info.implement.interfaces) {
						markClassUsed(i.iface.decl);
					}
				}
		}
	}

	override function processVarField(v:TVarField) {
		markTypeUsed(v.type);
		super.processVarField(v);
	}

	override function processSignature(sig:TFunctionSignature):TFunctionSignature {
		for (arg in sig.args) {
			markTypeUsed(arg.type);
		}
		markTypeUsed(sig.ret.type);
		return super.processSignature(sig);
	}

	override function processImport(i:TImport):Bool {
		var keep = switch i.kind {
			case TIDecl({kind: TDClassOrInterface(cls)}):
				usedClasses.exists(cls);
			case _:
				true;
		}
		// duplicates can happen when merging in out-of-package imports, keep only the first one
		return keep && !isDuplicate(i);
	}

	function isDuplicate(i:TImport):Bool {
		var key = switch i.kind {
			case TIDecl({kind: TDNamespace(_)}): return false; // not printed by GenHaxe anyway
			case TIDecl(d): "decl:" + declKey(d);
			case TIAliased(d, _, name): "alias:" + name.text + ":" + declKey(d);
			case TIAll(pack, _, _): "all:" + pack.name;
		}
		if (seenImports.exists(key)) {
			return true;
		}
		seenImports[key] = true;
		return false;
	}

	static function declKey(d:TDecl):String {
		return switch d.kind {
			case TDClassOrInterface(c): c.parentModule.parentPack.name + "::" + c.name;
			case TDVar(v): v.parentModule.parentPack.name + "::" + v.name;
			case TDFunction(f): f.parentModule.parentPack.name + "::" + f.name;
			case TDNamespace(_): throw "assert";
		}
	}

	inline function markClassUsed(cls:TClassOrInterfaceDecl) {
		usedClasses[cls] = true;
	}

	function markTypeUsed(t:TType) {
		switch t {
			case TTArray(t) | TTObject(t) | TTVector(t):
				markTypeUsed(t);
			case TTDictionary(k, v):
				markTypeUsed(k);
				markTypeUsed(v);
			case TTFun(args, ret, _):
				for (arg in args) {
					markTypeUsed(arg);
				}
				markTypeUsed(ret);
			case TTInst(cls) | TTStatic(cls):
				markClassUsed(cls);
			case TTVoid | TTAny | TTBoolean | TTNumber | TTInt | TTUint | TTString | TTFunction | TTClass | TTXML | TTXMLList | TTRegExp | TTBuiltin:
				// these are always imported
		}
	}
}
