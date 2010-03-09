package Twittary::Inbox::TypePadInvites;
use strict;
use warnings;

use base qw/Twittary::Inbox/;

__PACKAGE__->mk_accessors(qw/ user /);

use Twittary::API::User;
use Twittary::Model::User;
use Twittary::TypePad;
use Twittary::Core;

sub is_handler_for {
    my $class   = shift;
    my $message = shift;
    my $to      = $message->header('To') || "";
    return 1 if $to =~ /loudly/; 
}

sub process {
    my $self = shift;
    my $user = $self->find_user;    
    my $textref = $self->get_plain_text;
    my $typepad = Twittary::TypePad->new;
    my $blog_id = $typepad->accept_invite($textref);
    my $atom_uri = $typepad->atom_uri($blog_id);
    Twittary::Core->log->info(sprintf ("Added blog %s to %s (%s - %s)", 
        $blog_id, $user->name, $user->twitter_name, $user->user_id));
    Twittary::API::User->add_twittary_guest(uri => $atom_uri, user => $user);
    return 1;
}

sub find_user {
    my $self = shift;
    my $to = $self->message->header('To');
    my($shid) = $to =~ m/^\w+\+(\w+)\@/;
    die "no identified uid in $to" unless $shid;
    my $user = Twittary::Model::User->lookup_by_shid($shid)
        or die "sorry cannot find user corresponding to uid $shid";
    $self->user($user);
    return $user;
}

sub get_plain_text {
    my $self = shift;
    my $message = $self->message;
    my @plain_text = grep { $_->content_type =~ m{text/plain} } 
                     ( $message->parts, $message->subparts );
    my $first = shift @plain_text;
    return \$first->body;
}

1;
