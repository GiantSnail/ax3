package ax3.filters;

/**
	Rewrites the AS3 append idiom `arr[arr.length] = value` into `arr.push(value)`.

	Only applies when the value of the assignment is not used and the array
	expression is a side-effect-free reference that is structurally the same
	on both sides (so evaluating it once instead of twice is safe).
**/
class RewriteArrayPush extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(
				{kind: TEArrayAccess(a = {eindex: {kind: TEField({kind: TOExplicit(_, eLengthObj)}, "length", _)}})},
				OpAssign(_),
				eValue
			) if (e.expectedType == TTVoid
				&& a.eobj.type.match(TTArray(_) | TTVector(_))
				&& isSameReference(a.eobj, eLengthObj)):

				var elemType = switch a.eobj.type {
					case TTArray(t) | TTVector(t): t;
					case _: throw "assert";
				};
				var tPush = TTFun([elemType], TTUint);
				var fieldObj = {kind: TOExplicit(mkDot(), a.eobj), type: a.eobj.type};
				var eMethod = mk(TEField(fieldObj, "push", mkIdent("push")), tPush, tPush);
				removeLeadingTrivia(eValue);
				e.with(kind = TECall(eMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: [{expr: eValue.with(expectedType = elemType), comma: null}]
				}));

			case _:
				e;
		}
	}

	static function isSameReference(a:TExpr, b:TExpr):Bool {
		return switch [a.kind, b.kind] {
			case [TEParens(_, ia, _), _]: isSameReference(ia, b);
			case [_, TEParens(_, ib, _)]: isSameReference(a, ib);
			case [TELocal(_, va), TELocal(_, vb)]: va == vb;
			case [TELiteral(TLThis(_)), TELiteral(TLThis(_))]: true;
			case [TEField(oa, na, _), TEField(ob, nb, _)]: na == nb && isSameFieldObject(oa, ob);
			case [TEDeclRef(_, da), TEDeclRef(_, db)]: da == db;
			case _: false;
		}
	}

	static function isSameFieldObject(a:TFieldObject, b:TFieldObject):Bool {
		return switch [a.kind, b.kind] {
			case [TOImplicitThis(ca), TOImplicitThis(cb)]: ca == cb;
			case [TOImplicitClass(ca), TOImplicitClass(cb)]: ca == cb;
			case [TOExplicit(_, ea), TOExplicit(_, eb)]: isSameReference(ea, eb);
			// explicit `this.field` and implicit `field` refer to the same object
			// (a shadowing local would have been typed as TELocal, not an implicit field access)
			case [TOImplicitThis(_), TOExplicit(_, {kind: TELiteral(TLThis(_))})]: true;
			case [TOExplicit(_, {kind: TELiteral(TLThis(_))}), TOImplicitThis(_)]: true;
			// same for `Class.staticField` and implicit `staticField`
			case [TOImplicitClass(c), TOExplicit(_, {kind: TEDeclRef(_, {kind: TDClassOrInterface(cRef)})})]: c == cRef;
			case [TOExplicit(_, {kind: TEDeclRef(_, {kind: TDClassOrInterface(cRef)})}), TOImplicitClass(c)]: c == cRef;
			case _: false;
		}
	}
}
