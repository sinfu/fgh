
import std.typetuple;


//----------------------------------------------------------------------------//
// Example
//----------------------------------------------------------------------------//

enum Precision
{
    integral,
    single,
    maximum,
}

template Numeric(Precision precision)
{
    alias StaticSwitch!(precision)
            .Case!( Precision.integral, int   )
            .Case!( Precision.single  , float )
            .Case!( Precision.maximum , real  )
            .Finish Numeric;
}

static assert(is( Numeric!(Precision.integral) == int   ));
static assert(is( Numeric!(Precision.single  ) == float ));
static assert(is( Numeric!(Precision.maximum ) == real  ));

// -1 is not caught by any of the Case nodes, hence error on the Finish
static assert(!__traits(compiles, Numeric!(cast(Precision) -1) ));

alias Numeric!(cast(Precision) -1) K;


//----------------------------------------------------------------------------//
// StaticSwitch
//----------------------------------------------------------------------------//


private template isHeterogeneous(items...)
{
    enum isHeterogeneous = true;
}


// Switch-Case on non-heterogeneous enum members makes no sense.
private template isHeterogeneousEnum(T)
{
    static if (is(T == enum))
        enum isHeterogeneousEnum = isHeterogeneous!(EnumMembers!T);
    else
        enum isHeterogeneousEnum = false;
}


/**
 *
 *
--------------------
enum Precision
{
    integral,
    single,
    maximum,
}

template Numeric(Precision precision)
{
    alias StaticSwitch!(precision)
            .Case!( Precision.integral, int   )
            .Case!( Precision.single  , float )
            .Case!( Precision.maximum , real  )
            .Finish Numeric;
}

static assert(is( Numeric!(Precision.integral) == int   ));
static assert(is( Numeric!(Precision.single  ) == float ));
static assert(is( Numeric!(Precision.maximum ) == real  ));

alias Numeric!(cast(Precision) -1) error;   // Error!
--------------------
 *
 * $(D Otherwise) must be used for closing a switch-case chain if the
 * matched value is not an $(D enum).
--------------------
template Numeric(int which)
{
    alias StaticSwitch!(which)
           .Case!(1, int  )
           .Case!(2, float)
      .Otherwise!(   void ) Numeric;
}

static assert(is( Numeric!(1) == int   ));
static assert(is( Numeric!(2) == float ));
static assert(is( Numeric!(3) == void  ));  // fallback
--------------------
 */
template StaticSwitch(alias value, Enum = typeof(value))
    if (isHeterogeneousEnum!(Enum))
{
    // Install a Case/Finish/Otherwise chain.
    mixin GenerateNode!(State.unmatched, EnumMembers!Enum);


    //----------------------------------------------------------------//
private:

    enum State
    {
        unmatched,
        matched,
    }


    template Pack(      T) { alias T unpack; }
    template Pack(alias s) { alias s unpack; }


    // <unmatched>
    //     :
    //   .Case     !( cond, result )
    //   .Otherwise!(       result )
    template GenerateNode( State state : State.unmatched,
                           rest...)
    {
        static if (rest.length > 0)
        {
            template Case(Enum match, result...)
                if (result.length == 1)
            {
                private alias Erase!(match, rest) restNext;

                static if (value == match)
                {
                    mixin GenerateNode!( State.matched,
                                         Pack!(result[0]),
                                         restNext );
                }
                else
                {
                    mixin GenerateNode!( state, restNext );
                }
            }
        }


        template Otherwise(      result) { alias result Otherwise; }
        template Otherwise(alias result) { alias result Otherwise; }
    }


    // <matched>
    //     :
    //   .Case!( cond, result )
    //   .Finish
    template GenerateNode( State state : State.matched,
                           alias result,
                           rest... )
    {
        static if (rest.length > 0)
        {
            template Case(Enum match, _...)
                if (_.length == 1)
            {
                mixin GenerateNode!( state,
                                     result,
                                     Erase!(match, rest) );
            }
        }


        template Otherwise(      _) { alias result.unpack Otherwise; }
        template Otherwise(alias _) { alias result.unpack Otherwise; }


        // Finish must not be used if there are uncaught enum members.
        static if (rest.length == 0)
        {
            alias result.unpack Finish;
        }
    }
}




//----------------------------------------------------------------------------//
// Utilities
//----------------------------------------------------------------------------//


template Sequence(items...)
{
    alias items elements;
}


template EnumMembers(Enum)
    if (is(Enum == enum))
{
    alias EnumSpecificMembers!(Enum, __traits(allMembers, Enum)) EnumMembers;
}

private template EnumSpecificMembers(Enum, idents...)
    if (is(Enum == enum))
{
    static if (idents.length > 0)
    {
        alias TypeTuple!(
                __traits(getMember, Enum, idents[0]),
                EnumSpecificMembers!(Enum, idents[1 .. $])
            ) EnumSpecificMembers;
    }
    else
    {
        alias TypeTuple!() EnumSpecificMembers;
    }
}


