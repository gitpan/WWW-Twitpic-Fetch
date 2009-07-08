package WWW::Twitpic::Fetch;
use Moose;
use LWP::UserAgent;
use Web::Scraper;
use URI;
use Carp;
use List::MoreUtils qw/each_array/;
use Text::Trim;
use Encode;
use utf8;

=head1 NAME

WWW::Twitpic::Fetch - Moose-based information scraper/fetcher for Twitpic

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

	use WWW::Twitpic::Fetch;
	
	my $twitpic = WWW::Twitpic::Fetch->new();
	my $list = $twitpic->list($username, $page);
	my $photoinfo = $twitpic->photo_info($list->[0]{id}, 0);
	...

=head1 ATTRIBUTES

=head2 ua

LWP::UserAgent compatible UserAgent object.
default is an instance of LWP::UserAgent.

=head2 username

username for twitter (and also twitpic).
UNUSED for this version

=head2 password

password for twitter (and also twitpic).
UNUSED for this version 

=cut

has ua => (
	is => q/rw/,
	isa => q/Ref/,
	default => sub {
		my $ua = LWP::UserAgent->new;
		$ua->env_proxy;
		$ua;
	},
);

has username => (
	is => q/ro/,
	isa => q/Str/,
	#required => 1,
);

has password => (
	is => q/ro/,
	isa => q/Str/,
	#required => 1,
);

# private attributes

has _list_scraper => (
	is => q/ro/,
	lazy => 1,
	default => sub {
		scraper {
			process 'div.profile-photo-img>a' => 'id[]' => '@href';
			process 'div.profile-photo-img>a>img' => 'thumb[]' => '@src';
			process 'div.profile-photo-message' => 'message[]' => 'TEXT';
		};
	},
);

has _photo_full_scraper => (
	is => q/ro/,
	lazy => 1,
	default => sub {
		scraper {
			process 'div#pic>img' => 'url' => '@src';
		};
	},
);

has _photo_scaled_scraper => (
	is => q/ro/,
	lazy => 1,
	default => sub {
		my $each_comment = scraper {
			process 'div.photo-comment-info>a' => 'username' => 'TEXT';
			process 'div.photo-comment-info>span.photo-comment-date' => 'date' => 'TEXT';
			process 'div.photo-comment-message' => 'comment' => 'TEXT';
			process 'div.photo-comment-avatar>img' => 'avatar' => '@src';
		};
		scraper {
			process 'div#photo>img' => 'url' => '@src';
			process 'div#view-photo-views>div' => 'views' => 'TEXT';
			process 'div#view-photo-caption' => 'message' => 'TEXT';
			process 'div.photo-comment' => 'comments[]' => $each_comment;
		};
	},
);

has _public_timeline_scraper => (
	is => q/ro/,
	lazy => 1,
	default => sub {
		my $each = scraper {
			process 'img.avatar' => 'avatar' => '@src';
			process 'a.nav' => 'username' => 'TEXT';
			process 'td>div>a' => 'id[]' => '@href';
			process 'td>div' => 'message[]' => 'TEXT';
			process 'div>a>img' => 'mini' => '@src';
		};
		scraper {
			process 'div.comment>table>tr' => 'photos[]' => $each;
		};
	},
);

=head1 FUNCTIONS

=head2 list(USERNAME [, PAGE])

get list of photo informations for USERNAME.

returns arrayref of hashref containing following keys
'id', 'message', 'thumb' when success.
('id' is for each photo, and 'thumb' is for url of thumbnail image of photo)

returns undef if failed to fetch list.

=over 1

=item USERNAME (required)

specifies whose photo list.

=item PAGE

specifies page of list. can be omitted. (default = 1) 

=back

=cut

sub list
{
	my ($self, $username, $page) = @_;
	croak "invalid username: @{[$username?$username:'']}" if !$username;
	$page += 0 if $page;
	$page = 1 if !defined $page or $page < 1;

	my $ua = $self->ua;

	my $uri = URI->new('http://twitpic.com/photos/'.$username);
	if ( $page > 1 ) {
		$uri->query_form(page => $page);
	}
	my $res = $ua->get($uri);
	if ( !$res->is_success ) {
		return undef;
	}

	my $sres = $self->_list_scraper->scrape(decode_utf8($res->content));

	my ($ids, $messages, $thumbs) = map { $sres->{$_} } qw/id message thumb/;

	warn 'mismatch found for photo ids and messages. return value may be wrong'
	if !(scalar @$ids == scalar @$messages && scalar @$ids == scalar @$thumbs);

	$_ =~ s#^/## for @$ids;
	trim for @$messages;

	my $ea = each_array(@$ids, @$messages, @$thumbs);
	my @list;
	while (my ($id, $message, $thumb) = $ea->() ) {
		push @list, +{ id => $id, message => $message, thumb => $thumb };
	}

	\@list;
}
	
=head2 photo_info ID [, FULL?]

get informations of photo file.

returns following informations for scaled, 'url', 'message', 'comments', 'views'.
and for full-size, 'url'.

return undef if failed to fetch.

=over 1

=item ID (required)

photo id. you can get photo id by list() or public_timeline().

=item FULL?

FALSE for scaled photo. TRUE for full-size photo.
(default = FALSE).

=back

=cut

sub photo_info {
	my ($self, $id, $full) = @_;

	croak "invalid photo id: @{[$id?$id:'']}" if !$id;

	my $url = URI->new('http://twitpic.com/' . $id . ($full ? '/full' : ''));
	my $res = $self->ua->get($url);

	return undef if !$res->is_success;

	my $sres =
		($full ? $self->_photo_full_scraper : $self->_photo_scaled_scraper)
		->scrape(decode_utf8($res->content));
	return undef if !$sres;

	if ( $full ) {
		return $sres;
	}

	$sres->{views} =~ s/[^\d]*(\d+).*/$1/;
	trim $sres->{message};
	trim $_->{comment} for @{$sres->{comments}};

	$sres;
}

=head2 public_timeline

get information of photos on public_timeline

returns arrayref of hashref containing following.
'avatar', 'username', 'mini' and 'message' ('mini' means mini-thumbnail).

returns undef if failed to fetch

=cut

sub public_timeline
{
	my ($self) = @_;

	my $res = $self->ua->get('http://twitpic.com/public_timeline/');
	return undef if !$res->is_success;

	my $sres = $self->_public_timeline_scraper->scrape(decode_utf8($res->content));
	return undef if !$sres;

	for (@{$sres->{photos}}) {
		$_->{id} = pop @{$_->{id}};
		$_->{message} = pop @{$_->{message}};

		$_->{id} =~ s#^/##;
		trim $_->{message};
	}

	$sres->{photos};
}

=head1 SEEALSO

L<http://twitpic.com/> - Twitpic web site

L<WWW::Twitpic> - Diego Kuperman's Twitpic API client

=head1 AUTHOR

turugina, C<< <turugina at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-twitpic-fetch at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Twitpic-Fetch>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Twitpic::Fetch


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Twitpic-Fetch>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Twitpic-Fetch>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Twitpic-Fetch>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Twitpic-Fetch/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 turugina, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of WWW::Twitpic::Fetch
