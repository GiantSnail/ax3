package {
	import helpers.Helper;

	public class Test4 {
		public function Test4() {
			var h:Helper = new Helper();
			var p:Private = new Private();
			trace(h, p);
		}
	}
}

import helpers.Helper;

class Private {
	public var h:Helper;
	public function Private() {
		h = new Helper();
	}
}
