package {
	public class Test7Sub extends Test7 {
		public function Test7Sub() {
			super(1, "a");
			trace(this.$method()); // inherited $ method access
		}
		override protected function $method():int {
			return 43;
		}
	}
}
