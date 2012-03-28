package WWW::Vimeo::Download::Lite;

use strict;
use warnings;
use 5.008_001;
our $VERSION = '0.01';

use parent 'WWW::Mechanize';

use Carp qw(croak carp);
use JSON qw(decode_json);
use File::Basename qw(fileparse);
use Encode qw(find_encoding decode_utf8);

use constant IS_WIN32    => $^O eq 'MSWin32';
use constant IS_MAC      => $^O eq 'darwin';
use constant fs_encoding => find_encoding IS_WIN32 ? 'cp932' : 'utf8';

sub new {
    my ($class, %args) = @_;
    $args{agent} ||= __PACKAGE__ .' / '.$VERSION;
    my $self = $class->SUPER::new(%args, max_redirect => 0);
    $self->{verbose} = $args{verbose} ? 1 : 0;
    return $self;
}

sub verbose {
    @_ < 2 ? $_[0]->{verbose} : ($_[0]->{verbose} = $_[1]);
}

sub download {
    my ($self, $clip_id_or_url, %args) = @_;
    croak 'Usage: $client->download($clip_id_or_url)' unless $clip_id_or_url;
    my $clip_id = $self->_find_clip_id($clip_id_or_url);

    $self->get($self->_get_video_config_url($clip_id));
    $self->_die_if_error;

    my $video_config = decode_json +$self->content;
    unless ($video_config->{video} && $video_config->{request}) {
        carp sprintf '%s(L:%d): %s (clip_id: %s)',
            __PACKAGE__, __LINE__, $video_config->{message}, $clip_id;
        return;
    }
    $self->get($self->_get_play_redirect_url($clip_id, $video_config));
    $self->_die_if_error;

    my $video_url = $self->res->header('Location');
    my $save_filename = $self->_gen_filename($args{filename}, $video_url, $video_config);

    $self->_puts('getting -> %s ...', $save_filename, $video_url);
    $self->mirror($video_url, $save_filename);
    $self->_die_if_error;
    $self->_puts(" done.\n");

    return $video_url;
}

sub _puts {
    my ($self, $format, @args) = @_;
    return unless $self->verbose;
    local $| = 1;
    printf $format, @args;
}

sub _get_video_config_url {
    my ($self, $clip_id) = @_;
    sprintf 'http://player.vimeo.com/config/%s', $clip_id;
}

sub _get_play_redirect_url {
    my ($self, $clip_id, $video_config) = @_;
    my $play_redirect_uri = URI->new('http://player.vimeo.com/play_redirect');
    $play_redirect_uri->query_form({
        clip_id => $clip_id,
        sig     => $video_config->{request}{signature},
        time    => $video_config->{request}{timestamp},
        quality => 'hd',
    });
    $play_redirect_uri->as_string;
}

sub _find_clip_id {
    my ($self, $clip_id_or_url) = @_;
    my $clip_id = $clip_id_or_url;
    local $1;
    if ($clip_id_or_url =~ m{http://(?:www\.)?vimeo\.com/([^/]+)}i) {
        $clip_id = $1;
    }
    elsif ($clip_id_or_url =~ m{http://(?:www\.)?vimeo\.com/groups/(?:[^/]+)/videos/([^/]+)}i) {
        $clip_id = $1;
    }
    return $clip_id;
}

sub _die_if_error {
    my $self = shift;
    return unless $self->res->is_error;
    croak sprintf '%s %s', $self->res->status_line, $self->uri;
}

sub _gen_filename {
    my ($self, $template, $video_url, $video_config) = @_;
    my (undef, undef, $suffix) = fileparse +URI->new($video_url)->path, qr/\.[^.]*/;
    my $video = $video_config->{video};
    $video->{suffix} = $suffix;

    $template ||= '({:id:}) [{:owner.name:}] {:title:}{:suffix:}';
    $template =~ s#{:([\w\.]+):}#
        my $ret = my $match = $1;
        my $config = $video;
        for my $key (split '\.', $match) {
            $ret = $match, last unless ref $config;
            $ret = $config->{$key};
            last unless defined $ret;
            $config = $ret;
        }
        $ret;
    #eg;

    return $self->_normalize_filename($template);
}

my %win32_taboo = (
    '\\' => "\x{ffe5}", # ￥
    '/'  => "\x{ff0f}", # ／
    ':'  => "\x{ff1a}", # ：
    '*'  => "\x{ff0a}", # ＊
    '?'  => "\x{ff1f}", # ？
    '"'  => "\x{2033}", # ″
    '<'  => "\x{ff1c}", # ＜
    '>'  => "\x{ff1e}", # ＞
    '|'  => "\x{ff5c}", # ｜
);

sub _normalize_filename {
    my ($self, $filename) = @_;
    $filename = decode_utf8 $filename;
    IS_WIN32 ? $filename =~ s#([/:*?"<>|\\])#$win32_taboo{$1}#ge :
    IS_MAC   ? $filename =~ tr|/:|\x{ff0f}\x{ff1a}| :
               $filename =~ tr|/|\x{ff0f}|
    ;
    return fs_encoding->encode($filename);
}

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

WWW::Vimeo::Download::Lite - Download videos from Vimeo

=head1 SYNOPSIS

  use WWW::Vimeo::Download::Lite;

  my $client = WWW::Vimeo::Download::Lite->new;
  $client->download($clip_id_or_url);

=head1 DESCRIPTION

WWW::Vimeo::Download::Lite is a module to request and download video files from Vimeo.

This module is implemented as a child class of L<< WWW::Mechanize >>. And this module is B<< NO MOOSE >>.

=head1 METHOD

=head2 new(%args)

Create a new WWW::Vimeo::Download::Lite instance.

  my $client = WWW::Vimeo::Download::Lite->new(
      agent         => 'Lynx/2.8.5rel.1 libwww-FM/2.14 SSL-MM/1.4.1 GNUTLS/1.0.16',
      verbose       => 1,
      show_progress => 1,
  );

For more information to C<< %args >>, see also L<< WWW::Mechanize >>.

=head2 download($clip_id_or_url [, \%optsion]);

Download and save Vimeo video file.

  $client->download($clip_id_or_url);

L<< \%option >> details are:

=over

=item filename

Sets save filename.

  $client->download($clip_id_or_url, { filename => 'custom_save_filename.mp4' });

You can specify B<< template >> for filename. The template rules are:

  {:parameter_name:}

The L<< parameter_name >> can specify the parameter of the video config. The following values are probably available.

  id
  title
  width
  height
  duration
  suffix
  owner.name

Default template is

  ({:id:}) [{:owner.name:}] {:title:}{:suffix:}

=back

=head2 verbose($bool)

Sets / Gets verbose option

  say $client->verbose;
  $client->verbose(0);

=head1 AUTHOR

xaicron E<lt>xaicron {at} cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2012 - xaicron

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<< WWW::Mechanize >>

L<< WWW::Vimeo::Download >>

=cut
