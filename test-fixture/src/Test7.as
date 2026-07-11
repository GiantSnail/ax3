package {
	public class Test7 {
		private var $data:Array = [];
		private var data:String = "taken";
		public static var $instance:Test7;

		public function Test7($arg:int, arg:String) {
			var $foo:int = 1;
			var foo:int = 2;          // `foo` taken: $foo must not become foo
			var $bar:int = 3;         // no conflict: becomes bar
			$foo = $foo + foo + $bar + $arg;
			trace(foo, $foo, arg);
			this.$data.push($foo);
			$data.push(foo);
			Test7.$instance = this;
			$instance = $instance;
			var f:Function = function($x:int):int { return $x; };
			trace(f(1), $method());
		}

		protected function $method():int {
			return this.$method2();
		}

		private function $method2():int {
			return 42;
		}
	}
}
