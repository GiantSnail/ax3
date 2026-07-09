package {
	public class Test {
		private var items:Array = [];

		public function Test() {
			items[items.length] = "hello";
			var n:int = items.length;
			var s:String = "count: " + n;
			trace(s);
		}

		public function untypedDefault(a:*=null):* {
			return a;
		}
	}
}
