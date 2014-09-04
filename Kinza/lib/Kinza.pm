package Kinza;
use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Email;
use Dancer::Plugin::Passphrase;
use DateTime;

our $VERSION = '0.1';

$ENV{KZ_USER} && $ENV{KZ_PASS}
  or die 'Must set KZ_USER and KZ_PASS';

my $cfg = setting('plugins');
$cfg->{DBIC}{default}{user}     = $ENV{KZ_USER};
$cfg->{DBIC}{default}{password} = $ENV{KZ_PASS};

my $student_rs = schema()->resultset('Student');
my $term_rs    = schema()->resultset('Term');
my $course_rs  = schema()->resultset('Course');
my $pres_rs    = schema()->resultset('Presentation');
my $pass_rs    = schema()->resultset('PasswordReset');

my $now  = DateTime->now(time_zone => 'Europe/London');
my $live = '2014-09-04T12:45';

my %private = map { $_ => 1 } qw[/submit];

hook before => sub {
  if ($private{request->path_info} and ! session('user')) {
    session 'goto' => request->path_info;
    request->path_info('/login');
  }
};

hook before_template => sub {
  my $params = shift;
  $params->{email} = session('email');
};

get '/' => sub {
  if ($now le $live) {
    return template 'comingsoon';
  }
  my $error = session('error');
  session 'error' => undef;
  my $choices = session('choices');
  session 'choices' => undef;

  my $student;
  if (session('email')) {
    $student = $student_rs->find({
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
    courses => [ $course_rs->all ],
    terms   => [ $term_rs->all ],
  };
};

post '/save' => sub {
  if ($now le $live) {
    return template 'comingsoon';
  }
  my %params = params;

  session 'choices' => { reverse %params };

  # Check that student has signed up for five terms
  # And that all their courses are different
  # And that all courses are still available
  my $terms = 0;
  my %courses;
  my @unavailable;
  foreach (keys %params) {
    my $pres = $pres_rs->find({ id => $params{$_} });
    $terms += $pres->course->number_of_terms;
    $courses{$pres->course->id} = 1;
    push @unavailable, $pres->course->title . ' (' . $pres->term->name . ')'
      if $pres->full;
  }

  if ($terms != $term_rs->count) {
    session 'error' => 'You must register for four terms of courses';
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
  my $student = $student_rs->find({
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

Thank you for selecting your Kinza 2014/15 courses.

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
  my @students = $student_rs->search({
    verify => { '!=' => undef },
  });

  template 'dummies', { students => \@students };
};

get '/register' => sub {
  if ($now le $live) {
    return template 'comingsoon';
  }
  my $error = session('error');
  session 'error' => undef;
  template 'register', {
    error => $error,
  };
};

post '/register' => sub {
  if ($now le $live) {
    return template 'comingsoon';
  }
  unless (param('email')
    and param('password') and param('password2')) {
      session 'error' => 'You must fill in all values';
    return redirect '/register';
  }

  unless (param('password') eq param('password2')) {
    session 'error' => 'Password values are not the same';
    return redirect '/register';
  }

  if (my $user = $student_rs->find({
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
  my $user = $student_rs->create({
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
  if ($now le $live) {
    return template 'comingsoon';
  }
  my $code = param('code');

  my $student = $student_rs->find({
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
  if ($now le $live) {
    return template 'comingsoon';
  }
  my $student = $student_rs->find({
    email => session('email'),
  });

  if (!$student->verify) {
    return template 'verified';
  }

  template 'resend', { student => $student };
};

post '/resend' => sub {
  if ($now le $live) {
    return template 'comingsoon';
  }
  my $student = $student_rs->find({
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
  if ($now le $live) {
    return template 'comingsoon';
  }
  my $error = session('error');
  session 'error' => undef;
  template 'login', { error => $error };
};

post '/login' => sub {
  if ($now le $live) {
    return template 'comingsoon';
  }
  session 'email' => undef;
  session 'name'  => undef;

  unless (params->{email} and params->{password}) {
    session 'error' => 'Must give both email and password';
    return redirect '/login';
  }

  my $user = $student_rs->find({
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
  if ($now le $live) {
    return template 'comingsoon';
  }
  my $error = session('error');
  session 'error' => undef;
  template 'password', { error => $error };
};

post '/password' => sub {
  if ($now le $live) {
    return template 'comingsoon';
  }
  unless (params->{email}) {
    session 'error' => 'You must give an email address';
    return redirect '/password';
  }
  my $email = params->{email};
  my $student = $student_rs->find({
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
  if ($now le $live) {
    return template 'comingsoon';
  }
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
  if ($now le $live) {
    return template 'comingsoon';
  }
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

Thank you for registering for Kinza 2014/15.

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
