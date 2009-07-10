use Test::More tests => 10;

use WWW::Twitpic::Fetch;

my $tp = WWW::Twitpic::Fetch->new;

ok $tp;
can_ok $tp, qw/tagged/;

{ local $@;
	eval { $tp->tagged; };
	ok $@;
}

package UA1;
use Moose;
use HTTP::Response;
use Test::More;

sub get
{
	my (undef, $uri, @rest) = @_;

	is scalar(@rest), 0;
	is $uri, "http://twitpic.com/tag/cat";
	HTTP::Response->new(302);
}

package main;

$tp->ua(UA1->new);
ok !defined $tp->tagged('cat');

package UA2;
use Moose;
use HTTP::Response;
use Test::More;

sub get
{
	my (undef, $uri, @rest) = @_;

	is scalar(@rest), 0;
	is $uri, "http://twitpic.com/tag/cat";
	my $r = HTTP::Response->new(200);
	$r->content(<<EOS);
<html>
<body>
<div id="main">
<center>
<div style="font-size:18px;">Photos tagged with <b><em>cat</em></b></div>
<div style="padding-top:20px;">

	<a href="/abcde" title="title1"><img class="photo-mini" src="example1.jpg" alt="title1"></a>

	<a href="/12345" title="title2"><img class="photo-mini" src="example2.jpg" alt="title2"></a>
	</div:
</center>
</div>
</body>
</html>
EOS
	$r;
}

package main;

$tp->ua(UA2->new);
my $list = $tp->tagged('cat');
ok $list;
is_deeply $list, 
[
{ id => 'abcde',
	mini => 'example1.jpg',
},
{ id => '12345',
	mini => 'example2.jpg',
},
];

