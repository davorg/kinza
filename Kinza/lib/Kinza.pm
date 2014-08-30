package Kinza;
use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Email;
use Dancer::Plugin::Passphrase;

our $VERSION = '0.1';

$ENV{KZ_USER} && $ENV{KZ_PASS}
  or die 'Must set KZ_USER and KZ_PASS';

my $cfg = setting('plugins');
$cfg->{DBIC}{default}{user}     = $ENV{KZ_USER};
$cfg->{DBIC}{default}{password} = $ENV{KZ_PASS};

my $student_rs = schema()->resultset('Student');
my $term_rs    = schema()->resultset('Term');
my $course_rs  = schema()->resultset('Course');

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
    template 'index', {
      courses => [ $course_rs->all ],
      terms   => [ $term_rs->all ],
    };
};

get '/register' => sub {
    my $error = session('error');
    session 'error' => undef;
    template 'register', {
        error => $error,
    };
};

post '/register' => sub {
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

    my $body = <<EO_EMAIL;

Dear @{[$user->email]},

Thank you for registering for Kinza 2014/15.

Please click on the link below to verify your email address.

@{[uri_for('/verify')]}/$verify

EO_EMAIL

    email {
        from    => 'admin@cool-stuff.co.uk',
        to      => $user->email,
        subject => 'SCHS Kinza Verification',
        body    => $body,
    };

    template 'registered', { user => $user };
};

get '/verify/:code' => sub {
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

true;
