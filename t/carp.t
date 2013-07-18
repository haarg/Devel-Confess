use Test::More;
use Test::Fatal;
use Carp::Always::WithRefs;

{
  package MyException;
  
  sub new { bless {} }

  use overload '""' => sub { "here's my overloaded string" }
}

sub foo {
  die MyException->new;
}
foo();

ok 1;
done_testing;
