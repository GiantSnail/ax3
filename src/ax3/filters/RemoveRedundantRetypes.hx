package ax3.filters;

/**
	Final-step filter that removes `TEHaxeRetype` nodes that don't change the type,
	so we don't generate no-op `(expr : Type)` checks. These can be produced by earlier
	filters (e.g. `RewriteAs`) when the source contains an `as` cast to the value's own type.
**/
class RemoveRedundantRetypes extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEHaxeRetype(einner) if (typeEq(einner.type, e.type) && !needsParens(einner)):
				einner.with(expectedType = e.expectedType);
			case _:
				e;
		}
	}

	static function needsParens(e:TExpr):Bool {
		// removing the retype also removes the parentheses it would print,
		// so only unwrap expressions that never require parens in any context
		return switch e.kind {
			case TELocal(_) | TELiteral(_) | TEField(_) | TECall(_) | TEArrayAccess(_) | TEParens(_)
			   | TEDeclRef(_) | TEBuiltin(_) | TENew(_) | TEArrayDecl(_) | TEVectorDecl(_) | TEObjectDecl(_) | TECast(_):
				false;
			case _:
				true;
		}
	}
}
