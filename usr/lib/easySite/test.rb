require "./info"

str_root = '
<nil>
	0
	<one>
		1.0
		<one_one>
			1.1
		</one_one>
		<one_two>
			1.2
		</one_two>
	</one>
	<two>
		2.0
		<two_one>
			2.1
		</two_one>
		<two_two>
			2.2
		</two_two>
	</two>
	<three>
		3.0
		<three_one>
			3.1
		</three_one>
		<three_two>
			3.2
		</three_two>
	</three>
</nil>
'

$root = Info::new(str_root, '');
$root.initPaths []

$a = $root.child( [2,2] )
