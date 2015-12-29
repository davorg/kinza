package Kinza;
use 5.010;
use Dancer2 appname => 'Kinza';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Email;
use Dancer2::Plugin::Passphrase;
use DateTime;

our $VERSION = '0.1';

prefix '/reports';

my $cfg = config->{plugins};
$cfg->{DBIC}{default}{user}     = $ENV{KZ_USER};
$cfg->{DBIC}{default}{password} = $ENV{KZ_PASS};

my %rs = map {
  $_ => schema()->resultset($_)
} qw[Student Term Course Presentation PasswordReset];

get '/' => sub {
  template 'reports';
};

get '/form' => sub {
  content_type 'text/csv';
  header 'Content-Disposition' => 'attachment; filename="form.csv"';

  my $csv;
  my $terms = join ',', map { $_->name } $rs{Term}->search({}, { order_by => 'seq' })->all;

  foreach my $y (schema->resultset('Year')->search({}, {
      order_by => 'id',
    })) {
    $csv .= $y->name . "\n";

    foreach my $f ($y->forms->search({}, { order_by => 'id' })) {
      $csv .= $f->name . "\n";
      $csv .= "Name,$terms\n";

      foreach my $s ($f->students->search({}, { order_by => 'name' })) {
        $csv .= $s->name;
        my $term_seq = 1;
        foreach my $a ($s->sorted_attendances) {
          if ($a->presentation->term->seq == $term_seq++) {
            $csv .= ',"' . $a->presentation->course->title . '"';
          } else {
            $csv .= ',';
            redo;
          }
        }
        $csv .= "\n";
      }
    $csv .= "\n";
    }
  }

  return $csv;
};

get '/course' => sub {
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

get '/numbers' => sub {
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

true;
