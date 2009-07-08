use Test::More tests => 9;

use WWW::Twitpic::Fetch;


my $twitpic = WWW::Twitpic::Fetch->new;

ok $twitpic;
isa_ok $twitpic->ua, 'LWP::UserAgent';

{ local $@;
	eval { $twitpic->list; };
	ok $@;
}

package UA1;
use Moose;
use Test::More;
use HTTP::Response;
sub get
{
	my ($self, $uri, %param) = @_;
	is($uri, "http://twitpic.com/photos/hoge");
	is(scalar(keys %param), 0);
	return HTTP::Response->new(404);
}

package main;

$twitpic->ua(UA1->new);
ok !defined $twitpic->list('hoge');

package UA2;
use Moose;
use Test::More;
use HTTP::Response;

sub get
{
	my ($self, $uri, %param) = @_;
	is ($uri, "http://twitpic.com/photos/hige?page=2");
	is scalar(keys %param), 0;
	my $r = HTTP::Response->new(200);
	$r->content(<<EOS);
<html><head><title>TEST</title></head><body>
<div class="profile-photo-info">1 day ago from site</div>
<div class="profile-photo-img"><a href="/a7g60">
<img src="http://example.com/example.jpg" /></a></div>
<div class="profile-photo-message">
	TEST MESSAGE  
</div>
<div class="profile-photo-info">2 day ago from site</div>
<div class="profile-photo-img"><a href="/J89Tt">
<img src="http://example.com/example.png" /></a></div>
<div class="profile-photo-message">
	TEST MESSAGE 2nd			
</div>
</body>
</html>
EOS
	$r;
}

package main;

$twitpic->ua(UA2->new);
is_deeply($twitpic->list('hige', 2), 
	[
	{id => 'a7g60', message => 'TEST MESSAGE', thumb => 'http://example.com/example.jpg'},
	{id => 'J89Tt', message => 'TEST MESSAGE 2nd', thumb => 'http://example.com/example.png'},
	]
);
