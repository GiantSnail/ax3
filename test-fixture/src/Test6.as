package {
	import helpers.Helper

	public class Test6 {
		private var count:int = 0
		private static const MAX:int = 100

		public function Test6() {
			var h:Helper = new Helper()
			var a:int = 1
			var b:int = a + 2
			b = a +
				3
			count++
			count--
			trace(h, a, b, count)
			do {
				a++
			} while (a < 5)
			var arr:Array = []
			arr[arr.length] = a
			if (a > 0) {
				trace("positive")
			}
			for (var i:int = 0; i < 3; i++) {
				trace(i)
			}
		}

		public function noValue():void {
			return
		}

		public function restricted():int {
			var done:Boolean = true
			if (done) {
				return
				trace("dead code")
			}
			return 5
		}

		public function postfixRestricted():int {
			var a:int = 1
			var b:int = 2
			a = b
			++a
			return a /* multi
			line comment */
		}
	}
}
