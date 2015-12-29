package Kinza;
use 5.010;
use Dancer2;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Email;
use Dancer2::Plugin::Passphrase;
use DateTime;
use DateTime::Format::Strptime;

use Kinza::Reports;

our $VERSION = '0.1';

prefix undef;

my @envs = qw[ KZ_USER KZ_PASS KZ_HOST
               KZ_DOMAIN KZ_REG_OPEN KZ_SEL_OPEN ];

if (my @missing = grep { ! defined $ENV{$_} } @envs) {
  die 'You must set ', join(', ', @missing[0 .. $#missing - 1]),
      (@missing > 1 ? ' and ' : ''), $missing[-1];
}

my $cfg = config->{plugins};
$cfg->{DBIC}{default}{user}     = $ENV{KZ_USER};
$cfg->{DBIC}{default}{password} = $ENV{KZ_PASS};

my %rs = map {
  $_ => schema()->resultset($_)
} qw[Year Student Term Course Presentation PasswordReset];

my $dt_p = DateTime::Format::Strptime->new(
  pattern   => '%Y-%m-%dT%H:%M',
  time_zone => 'Europe/London',
  on_error  => 'croak',
);
my $now      = DateTime->now(time_zone => 'Europe/London');
my $reg_live = $dt_p->parse_datetime($ENV{KZ_REG_OPEN});
my $sel_live = $dt_p->parse_datetime($ENV{KZ_SEL_OPEN});
my $closed   = $dt_p->parse_datetime($ENV{KZ_CLOSED});

my %private  = map { $_ => 1 } qw[/submit];
my %open     = map { $_ => 1, "$_/" => 1 }
  qw[/closed /years /reports /courses
     /reports/form /reports/course /reports/numbers];
my %reg_open = (%open, map { $_ => 1 } qw[/register]);

hook before => sub {
  if ($now > $closed && ! $open{request->path_info}) {
    forward '/closed';
  }
  if ($now < $reg_live && ! $open{request->path_info}) {
    forward '/closed';
  }
  if (session('name') && $now < $sel_live && ! $open{request->path_info}) {
    forward '/closed';
  }
  if ($private{request->path_info} and ! session('user')) {
    session 'goto' => request->path_info;
    request->path_info('/login');
  }
};

hook before_template => sub {
  my $params = shift;
  $params->{email}  = session('email');
  $params->{domain} = $ENV{KZ_DOMAIN};
  $params->{reg_live} = $reg_live;
  $params->{sel_live} = $sel_live;
  if (session('email') and ! $params->{student}) {
    $params->{student} = $rs{Student}->find({
      email => session('email')
    }, {
      prefetch => { form => 'year' },
    });
  }

  if (!session('email')) {
    delete $params->{student};
  }
};

get '/closed' => sub {
  if ($now > $closed) {
    return template 'closed';
  } elsif ($now < $reg_live) {
    return template 'comingsoon';
  } else {
    return template 'sel_closed';
  }
};

get '/' => sub {
  my $error = session('error');
  session 'error' => undef;
  my $choices = session('choices');
  session 'choices' => undef;

  my $student;
  if (session('email')) {
    $student = $rs{Student}->find({
      email => session('email'),
    }, {
      prefetch => [{ attendances => 'presentation' }, { form => 'year' } ],
    });
  }

  if (!keys %$choices and $student) {
    $choices = $student->choices;
  }

  my @terms = $rs{Term}->search({}, {
    prefetch => { presentations => ['course', 'attendances'] },
    order_by => 'seq',
  })->all;

  my %term_course;
  foreach my $t (@terms) {
    foreach my $p ($t->presentations) {
      $term_course{$t->id}{$p->course_id} = $p;
    }
  }

  template 'index', {
    error   => $error,
    choices => $choices,
    student => $student,
    terms   => \@terms,
    term_course => \%term_course,
  };
};

post '/save' => sub {
  my %params = params;

  session 'choices' => { reverse %params };

  # Check that student has signed up for all terms
  # And that all their courses are different
  # And that all courses are still available
  my $terms = 0;
  my %courses;
  my @unavailable;

  my @pres = $rs{Presentation}->search({
    'me.id' => [ values %params],
  }, {
    prefetch => [ 'course', 'term', 'attendances' ],
  });

  foreach my $pres (@pres) {
    $terms += $pres->number_of_terms;
    $courses{$pres->course->id} = 1;
    push @unavailable, $pres->course->title . ' (' . $pres->term->name . ')'
      if $pres->full;
  }

  if ($terms != $rs{Term}->count) {
    session 'error' => 'You must register for three terms of courses';
    return redirect '/';
  }

  if (keys %courses != keys %params) {
    session 'error' => 'You must register for a different course each term';
    return redirect '/';
  }

  if (@unavailable) {
    session 'error', 'The following courses are full for your chosen terms:' .
      '<ul><li>' . join('</li><li>', @unavailable) . '</li></ul>';
    return redirect '/';
  }

  # Save the data
  my $student = $rs{Student}->find({
    email => session('email'),
  });

  schema->txn_do(sub {
    $student->attendances->delete;

    foreach (keys %params) {
      $student->add_to_attendances({
        presentation_id => $params{$_},
      });
    }
  });

  $student->discard_changes;

  my $body = <<EO_EMAIL;

Dear @{[$student->name]},

Thank you for selecting your Kinza 2015/16 courses.

The courses you hace chosen are as follows:

EO_EMAIL

  foreach ($student->sorted_attendances) {
    $body .= '* ' . $_->presentation->term->name . ' / ' .
      $_->presentation->course->title . "\n";
  }

  email {
    from    => 'admin@kinza.me',
    to      => $student->email,
    subject => 'SCHS Kinza Selection',
    body    => $body,
  };


  template 'saved', { student => $student };
};

get '/dummies' => sub {
  my @students = $rs{Student}->search({
    verify => { '!=' => undef },
  });

  template 'dummies', { students => \@students };
};

get '/reports' => sub {
  return redirect '/reports/';
};

get '/register' => sub {
  my $error = session('error');
  session 'error' => undef;
  template 'register', {
    error => $error,
  };
};

post '/register' => sub {
  my ($email, $pass1, $pass2);

  session 'error', undef;

  unless ($email = lc param('email')
    and $pass1 = param('password') and $pass2 = param('password2')) {
    session 'error' => 'You must fill in all values';
    return redirect '/register';
  }

  if ($email !~ /\@\Q$ENV{KZ_DOMAIN}/) {
    session 'error' => "You must use your \@$ENV{KZ_DOMAIN} email address";
    return redirect '/register';
  }

  unless ($pass1 eq $pass2) {
    session 'error' => 'Password values are not the same';
    return redirect '/register';
  }

  my $user = $rs{Student}->find({
    email => $email,
  });

  if (!$user) {
    session 'error' => "Email address $email is unknown.";
    return redirect '/register';
  }

  if ($user->password) {
    session 'error', $user->name . ' (' . $user->email . ') is already registered.'
            . '<br>Please <a href="/login">log in</a> instead.</p>';
    return redirect '/register';
  }

  my $verify = passphrase->generate_random({
    length  => 32,
    charset => [ 'a' .. 'z', '0' .. '9' ],
  });
  $user->update({
    password => passphrase($pass1)->generate->rfc2307,
    verify   => $verify,
  });

  # reread from database
  $user->discard_changes;
  send_verify($user);

  template 'registered', { user => $user };
};

get '/verify/:code' => sub {
  my $code = param('code');

  my $student = $rs{Student}->find({
    verify => $code,
  });

  if ($student) {
    $student->update({
      verify => undef,
    });

    template 'verified';
  } else {
    template 'unverified';
  }
};

get '/resend' => sub {
  my $student = $rs{Student}->find({
    email => session('email'),
  });

  if (!$student->verify) {
    return template 'verified';
  }

  template 'resend', { student => $student };
};

post '/resend' => sub {
  my $student = $rs{Student}->find({
    email => session('email'),
  });

  if (!$student->verify) {
    return template 'verified';
  }

  $student->update({
    email => lc param('email'),
  });
  # reread from database
  $student->discard_changes;
  if (send_verify($student)) {
    template 'registered', { user => $student };
  } else {
    template 'verified';
  }
};

get '/login' => sub {
  my $error = session('error');
  session 'error' => undef;
  template 'login', { error => $error };
};

post '/login' => sub {
  session 'email' => undef;
  session 'name'  => undef;

  unless (params->{email} and params->{password}) {
    session 'error' => 'Must give both email and password';
    return redirect '/login';
  }

  my $user = $rs{Student}->find({
    email => lc params->{email},
  });
  unless ($user) {
    session 'error' => 'Invalid email or password';
    return redirect '/login';
  }

  unless (passphrase(params->{password})->matches($user->password)) {
    session 'error' => 'Invalid email or password';
    return redirect '/login';
  }

  session 'email' => $user->email;
  session 'name'  => $user->name;

  if (my $goto = session('goto')) {
    session 'goto' => undef;
    redirect $goto;
  } else {
    redirect '/';
  }
};

get '/logout' => sub {
  session 'email' => undef;
  session 'name'  => undef;
  redirect '/';
};

get '/password' => sub {
  my $error = session('error');
  session 'error' => undef;
  template 'password', { error => $error };
};

post '/password' => sub {
  unless (params->{email}) {
    session 'error' => 'You must give an email address';
    return redirect '/password';
  }
  my $email = lc params->{email};
  my $student = $rs{Student}->find({
    email => $email,
  });
  unless ($student) {
    session 'error' => "$email is not a registered email address";
    return redirect '/password';
  }

  my $pass_code = passphrase->generate_random({
    length  => 32,
    charset => [ 'a' .. 'z', '0' .. '9' ],
  });

  $student->add_to_password_resets({
    code => $pass_code,
  });

  my $body = <<EO_EMAIL;

Dear @{[$student->name]},

Here is your password reset link.

Please click on the link below to set a new password.

@{[uri_for('/passreset')]}/$pass_code

EO_EMAIL

  email {
    from    => 'admin@kinza.me',
    to      => $student->email,
    subject => 'SCHS Kinza Password Change Request',
    body    => $body,
  };

  template 'pass_sent', { student => $student };
};

get '/passreset/:code' => sub {
  my $code = param('code');
  my $ps = schema->resultset('PasswordReset')->find({
    code => $code,
  });

  unless ($ps) {
    session 'error' => "Code '$code' is not recognised. Please try again.";
    return redirect '/password';
  }

  session 'code' => $code;
  template 'passreset', { code => $code };
};

post '/passreset' => sub {
  my $code = session('code');

  unless ($code) {
    session 'error' => 'Something went wrong.';
    redirect '/password';
  }

  my $ps = schema->resultset('PasswordReset')->find({
    code => $code,
  });

  unless ($ps) {
    session 'error' => "Code '$code' is not recognised. Please try again.";
    redirect '/password';
  }

  my $error;
  unless (param('password') and param('password2')) {
    $error = 'You must fill in both passwords';
  }

  unless (param('password') eq param('password2')) {
    $error = 'Password values are not the same';
  }

  if ($error) {
    return template 'passreset', { error => $error };
  }

  schema->txn_do(sub {
    $ps->student->update({
      password => passphrase(param('password'))->generate->rfc2307,
    });

    $ps->delete;
  });


  template 'passdone';
};

get '/years' => sub {
  template 'years', { years => $rs{Year} };
};

get '/courses' => sub {
  template 'courses', {
    courses => $rs{Course},
    years   => $rs{Year},
    terms   => $rs{Term},
  };
};

sub send_verify {
  my ($student) = @_;

  return unless $student->verify;

  my $body = <<EO_EMAIL;

Dear @{[$student->name]},

Thank you for registering for Kinza 2015/16.

Please click on the link below to verify your email address.

@{[uri_for('/verify')]}/@{[$student->verify]}

EO_EMAIL

  email {
    from    => 'admin@kinza.me',
    to      => $student->email,
    subject => 'SCHS Kinza Verification',
    body    => $body,
  };
}

true;
