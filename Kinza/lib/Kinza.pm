package Kinza;
use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Passphrase;

our $VERSION = '0.1';

$ENV{KZ_USER} && $ENV{KZ_PASS}
  or die 'Must set KZ_USER and KZ_PASS';

my $cfg = setting('plugins');
$cfg->{DBIC}{default}{user}     = $ENV{KZ_USER};
$cfg->{DBIC}{default}{password} = $ENV{KZ_PASS};

my $student_rs = schema()->resultset('Student');

my %private = map { $_ => 1 } qw[/submit];

hook before => sub {
    if ($private{request->path_info} and ! session('user')) {
        session 'goto' => request->path_info;
        request->path_info('/login');
    }
};

hook before_template => sub {
    my $params = shift;
    $params->{user} = session('user');
};


get '/' => sub {
    template 'index';
};

get '/register' => sub {
    my $error = session('error');
    session 'error' => undef;
    template 'register', {
        error => $error,
    };
};

post '/register' => sub {
    session 'email' => param('email');
    unless (param('email')
        and param('password') and param('password2')) {

        session 'error' => 'You must fill in all values';
        return redirect '/register';
    }

    unless (param('password') eq param('password2')) {
        session 'error' => 'Password values are not the same';
        return redirect '/register';
    }

    if (my $user = $student_rs->single({
        email => param('email'),
    })) {
        session 'error' => 'Email ' . $user->email .
            ' is already in registered.';
        return redirect '/register';
    }

    my $user = $student_rs->create({
        email => param('email'),
        password => passphrase(param('password'))->generate_hash,
    });

    template 'registered', { user => $user };
};

get '/login' => sub {
    my $error = session('error');
    session 'error' => undef;
    template 'login', { error => $error };
};

post '/login' => sub {
    session 'user' => undef;
    session 'email' => params->{email};
    unless (params->{email} and params->{pass}) {
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
    
    unless (passphrase(params->{pass})->matches($user->password)) {
        session 'error' => 'Invalid email or password';
        return redirect '/login';
    }
    
    session 'user' => $user->email;

    if (my $goto = session('goto')) {
        session 'goto' => undef;
        redirect $goto;
    } else {
        redirect '/';
    }
};

get '/logout' => sub {
    session 'user' => undef;
    redirect '/';
};

true;
