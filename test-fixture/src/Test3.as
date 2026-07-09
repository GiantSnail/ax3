package {
	public class Test3 {
		private var items:Array = [];
		private static var stat:Array = [];

		public function Test3(v:Vector.<int>) {
			var local:Array = [];
			local[local.length] = 1;                    // rewrite
			items[items.length] = 2;                    // rewrite (implicit this)
			this.items[items.length] = 3;               // rewrite (explicit/implicit mix)
			stat[stat.length] = 4;                      // rewrite (static)
			v[v.length] = 5;                            // rewrite (vector)
			local[items.length] = 6;                    // keep: different arrays
			local[local.length - 1] = 7;                // keep: not a plain length index
			var x:int = local[local.length] = 8;        // keep: value is used
			foo()[foo().length] = 9;                    // keep: not side-effect free
			trace(x);
		}

		private function foo():Array { return items; }
	}
}
