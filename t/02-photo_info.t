use Test::More tests => 17;

use WWW::Twitpic::Fetch;

my $twitpic = WWW::Twitpic::Fetch->new;

ok $twitpic;

{ local $@;
	eval { $twitpic->photo_info; };
	ok $@;
}
{ local $@;
	eval { $twitpic->photo_info('invalid_id'); };
	ok $@;
}

package UA1;
use Moose;
use Test::More;
use HTTP::Response;

sub get
{
	my (undef, $uri) = @_;
	is $uri, "http://twitpic.com/1bc34x";
	HTTP::Response->new(404);
}

package main;

$twitpic->ua(UA1->new);
ok !defined $twitpic->photo_info('1bc34x');

package UA2;
use Moose;
use Test::More;
use HTTP::Response;

sub get
{
	my (undef, $uri) = @_;
	is $uri, "http://twitpic.com/1bc34x";
	my $r = HTTP::Response->new(200);
	$r->content(<<EOS);
<html>
<head>
</head>
<body>
<div id="photo">
	<img id="photo-display" class="photo-large" src="example-scaled.jpg" />
	<div id="view-photo-caption">
		TEST MESSAGE</div>
</div>
<div class="photo-comment">
	<div class="photo-comment-avatar">
		<img class="avatar" width="48" height="48" src="avator.jpg" />
	</div>
	<div class="photo-comment-body">
		<div class="photo-comment-info" style="float:left;width:400px;">
		<a class="nav" href="/photos/hoge">hoge</a> <span class="photo-comment-date" style="">on June 22, 2009</span>
		</div>
						<div class="photo-comment-message" style="clear:both;">
		TEST COMMENT
	</div>
</div>
<div id="view-photo-views">
	<div style="font-size:14px;"><b>Views</b> 34</div>

</div>
</body>
</html>
EOS
	$r;
}

package main;

$twitpic->ua(UA2->new);

my $res = $twitpic->photo_info("1bc34x");

ok $res;

is_deeply $res, { 
	url => "example-scaled.jpg",
	message => "TEST MESSAGE",
	views => 34,
	comments => [{
		avatar => "avator.jpg",
		username => "hoge",
		date => "on June 22, 2009",
		comment => "TEST COMMENT",
	}],
};

package UA3;
use Moose;
use Test::More;
use HTTP::Response;

sub get
{
	my (undef, $uri) = @_;
	is $uri, "http://twitpic.com/1bc34x/full";
	my $r = HTTP::Response->new(200);
	$r->content(<<EOS);
<html>
<head>
</head>
<body>
<div id="main-full">
	<div id="pic" style="padding-top:25px;">
		<img class="photo-large" src="example-full.png" />
	</div>
</div>
</body>
</html>
EOS
	$r;
}

package main;

$twitpic->ua(UA3->new);

$res = $twitpic->photo_info("1bc34x", 1);

ok $res;

is_deeply $res, { 
	url => "example-full.png",
};

$res = $twitpic->photo_info("http://twitpic.com/1bc34x", 1);

ok $res;

is_deeply $res, { 
	url => "example-full.png",
};

$res = $twitpic->photo_info("http://www.twitpic.com/1bc34x/full", 1);

ok $res;

is_deeply $res, { 
	url => "example-full.png",
};


