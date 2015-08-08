package Kinza;
use 5.010;
use Dancer2;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Email;
use Dancer2::Plugin::Passphrase;
use DateTime;

our $VERSION = '0.1';

$ENV{KZ_USER} && $ENV{KZ_PASS}
  or die 'Must set KZ_USER and KZ_PASS';

my $cfg = config->{plugins};
$cfg->{DBIC}{default}{user}     = $ENV{KZ_USER};
$cfg->{DBIC}{default}{password} = $ENV{KZ_PASS};

my %rs = map {
  $_ => schema()->resultset($_)
} qw[Student Term Course Presentation PasswordReset];

my $now  = DateTime->now(time_zone => 'Europe/London');
my $live = '2015-08-04T12:45';

my %private = map { $_ => 1 } qw[/submit];
my %open    = map { $_ => 1 } qw[/closed];

hook before => sub {
  if ($open{request->path_info} and $now lt $live) {
    forward '/closed';
  }
  if ($private{request->path_info} and ! session('user')) {
    session 'goto' => request->path_info;
    request->path_info('/login');
  }
};

hook before_template => sub {
  my $params = shift;
  $params->{email} = session('email');
};

get '/closed' => sub {
  return template 'comingsoon';
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
    });
  }

  if (!keys %$choices and $student) {
    $choices = $student->choices;
  }

  template 'index', {
    error   => $error,
    choices => $choices,
    student => $student,
    courses => [ $rs{Course}->all ],
    terms   => [ $rs{Term}->all ],
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
  foreach (keys %params) {
    my $pres = $rs{Presentation}->find({ id => $params{$_} });
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
  template 'reports';
};

get '/reports/form' => sub {
  content_type 'text/csv';
  header 'Content-Disposition' => 'attachment; filename="form.csv"';

  my $csv;
  my $terms = join ',', map { $_->name } $rs{Term}->all;

  foreach my $y (schema->resultset('Year')->search({}, {
      order_by => 'id',
    })) {
    $csv .= $y->name . "\n";

    foreach my $f ($y->forms->search({}, { order_by => 'id' })) {
      $csv .= $f->name . "\n";
      $csv .= "Name,$terms\n";

      foreach my $s ($f->students->search({}, { order_by => 'name' })) {
        $csv .= $s->name;
        foreach my $a ($s->sorted_attendances) {
          $csv .= ',"' . $a->presentation->course->title . '"';
        }
        $csv .= "\n";
      }
    $csv .= "\n";
    }
  }

  return $csv;
};

get '/reports/course' => sub {
  content_type 'text/csv';
  header 'Content-Disposition' => 'attachment; filename="course.csv"';

  my $csv;

  foreach my $p ($rs{Presentation}->search({}, { order_by => 'id' })) {
    $csv .= '"' . $p->course->title . '/' . $p->term->name . qq["\n];
    foreach my $a ($p->attendances) {
      $csv .= $a->student->name. "\n";
    }
    $csv .= "\n";
  }

  return $csv;
};

get '/reports/numbers' => sub {
  content_type 'text/csv';
  header 'Content-Disposition' => 'attachment; filename="numbers.csv"';

  my @terms = $rs{Term}->all;
  my $csv = 'Course,' . join(',', map { $_->name} @terms) . "\n";

  foreach my $c ($rs{Course}->search({}, { order_by => 'title' })) {
    $csv .= '"' . $c->title . '"';
    foreach my $t (@terms) {
      if (my $p = $t->presentations->find({ course_id => $c->id })) {
        $csv .= ',' . $p->attendances->count;
      } else {
        $csv .= ',';
      }
    }
    $csv .= "\n";
  }

  return $csv;
};

get '/register' => sub {
  my $error = session('error');
  session 'error' => undef;
  template 'register', {
    error => $error,
  };
};

post '/register' => sub {
  unless (param('name') and param('email')
    and param('password') and param('password2')) {
      session 'error' => 'You must fill in all values';
    return redirect '/register';
  }

  unless (param('password') eq param('password2')) {
    session 'error' => 'Password values are not the same';
    return redirect '/register';
  }

  if (my $user = $rs{Student}->find({
    email => param('email'),
  })) {
    session 'error' => 'Email ' . $user->email .
      ' is already registered.';
    return redirect '/register';
  }

  my $verify = passphrase->generate_random({
    length  => 32,
    charset => [ 'a' .. 'z', '0' .. '9' ],
  });
  my $user = $rs{Student}->create({
    name     => param('name'),
    email    => param('email'),
    password => passphrase(param('password'))->generate->rfc2307,
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
    email => param('email'),
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
    email => params->{email},
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
  my $email = params->{email};
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
