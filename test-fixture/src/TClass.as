package
{

    public class TClass {

        private var name:String;

        public function show($name:String):void{

            name = $name;
            trace($name);
        }

        public function addAge($age:int):int{
            var age:int = $age+1;
            return age;
        }
    }
}
