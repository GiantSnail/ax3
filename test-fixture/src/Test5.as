package {
	public class Test5 {
		public function Test5() {
			var o:Object = {};
			var p:Object = o as Object;
			var q:Object = getIt() as Object;
			trace(p, q);
		}
		private function getIt():* { return null; }
	}
}
