
import std.typetuple : TypeTuple;
import fgh.meta      : isSame;  // isSame!( ... )


//----------------------------------------------------------------------------//
// Example
//----------------------------------------------------------------------------//


// switch over enum, return a type

enum Precision
{
    integral,
    single,
    maximum,
}

alias StaticSwitch!( Precision.single )
        .Case!( Precision.integral, int   )
        .Case!( Precision.single  , float )
        .Case!( Precision.maximum , real  )
        .Finish T;
static assert(is(T == float));


// switch over type, return a constant

enum a = StaticSwitch!( real )
        .Case!(  int, "integer"        )
        .Case!( real, "floating point" )
   .Otherwise!(       "dunno"          );

static assert(a == "floating point");



//----------------------------------------------------------------------------//
// StaticSwitch
//----------------------------------------------------------------------------//


/**
 * .
 */
template StaticSwitch(alias target, alias equal = isSame)
{
    // Install Case/Finish/Otherwise nodes.
    mixin GenerateNode!(Condition.init, SwitchState!target);


    //----------------------------------------------------------------//
private:

    enum Condition
    {
        unmatched,
        matched,
    }


    template Pack(      T   ) { alias T unpack; }
    template Pack(alias s   ) { alias s unpack; }
//  template Pack(      t...) { alias t unpack; }


    // Update the state to reflect that 'Cast!(match, ...)' is consumed.
    template popCase(alias state, alias match)
    {
        alias state.pop!(match) popCase;

        static assert(!__traits(isSame, state, popCase),
                      "Invalid case: " ~ match.stringof);
    }


    // <unmatched>
    //     :
    //  .Case     !( cond, result )
    //  .Otherwise!(       result )
    //
    template GenerateNode(Condition condition : Condition.unmatched,
                          alias state)
    {
        template Case(alias match, Result)
        {
            alias GenericCase_!(match, Pack!Result) Case;
        }

        template Case(alias match, alias result)
        {
            alias GenericCase_!(match, Pack!result) Case;
        }

//      template Case(alias match, result...)
//      {
//          alias GenericCase_!(match, Pack!result) Case;
//      }


        // Using an Otherwise node under the unmatched state yields the
        // specified default value.
        template Otherwise(      Result   ) { alias Result Otherwise; }
        template Otherwise(alias result   ) { alias result Otherwise; }
//      template Otherwise(      result...) { alias result Otherwise; }


        // Recursively install Case/Finish/Otherwise nodes.
        private template GenericCase_(alias match, alias result)
        {
            private alias popCase!(state, match) nextState;

            static if (equal!(target, match))
                mixin GenerateNode!(Condition.matched, nextState, result);
            else
                mixin GenerateNode!(Condition.unmatched, nextState);
        }
    }


    // <matched>
    //     :
    //  .Case!( cond, result )
    //  .Finish
    //
    template GenerateNode(Condition condition : Condition.matched,
                          alias     state,
                          alias     result)
    {
        // Under the matched state Case just propagates the result.
        template Case(alias match, _...)
        {
            mixin GenerateNode!(
                    condition, popCase!(state, match), result);
        }


        // Otherwise yields the propagated result.
        template Otherwise(_...) { alias result.unpack Otherwise; }


        // Finish must not be exposed if there are uncaught cases.
        static if (state.finished) alias result.unpack Finish;
    }
}


unittest    // switch-case-finish over enum
{
    enum YesNo
    {
        yes, no, dunno
    }

    alias StaticSwitch!( YesNo.yes )
            .Case!( YesNo.yes  , int    )
            .Case!( YesNo.no   , real   )
            .Case!( YesNo.dunno, string )
            .Finish A;
    static assert(is(A == int));

    alias StaticSwitch!( YesNo.no )
            .Case!( YesNo.yes  , int    )
            .Case!( YesNo.no   , real   )
            .Case!( YesNo.dunno, string )
            .Finish B;
    static assert(is(B == real));

    alias StaticSwitch!( YesNo.dunno )
            .Case!( YesNo.yes  , int    )
            .Case!( YesNo.no   , real   )
            .Case!( YesNo.dunno, string )
            .Finish C;
    static assert(is(C == string));

    // not covered
    static assert(!__traits(compiles,
            StaticSwitch!( YesNo.dunno )
                .Case!( YesNo.yes, int  )
                .Case!( YesNo.no , real )
                .Finish ));

    // not covered but matches
    static assert(!__traits(compiles,
            StaticSwitch!( YesNo.yes )
                .Case!( YesNo.yes, int  )
                .Case!( YesNo.no , real )
                .Finish ));

    // no match
    static assert(!__traits(compiles,
            StaticSwitch!( cast(YesNo) -1 )
                .Case!( YesNo.yes  , int    )
                .Case!( YesNo.no   , real   )
                .Case!( YesNo.dunno, string )
                .Finish ));
}

unittest    // switch-case-otherwise over enum
{
    enum YesNo
    {
        yes, no, dunno
    }

    alias StaticSwitch!( YesNo.yes )
            .Case!( YesNo.yes, int  )
            .Case!( YesNo.no , real )
       .Otherwise!(            void ) A;
    static assert(is(A == int));

    alias StaticSwitch!( YesNo.dunno )
            .Case!( YesNo.yes, int  )
            .Case!( YesNo.no , real )
       .Otherwise!(            void ) B;
    static assert(is(B == void));

    alias StaticSwitch!( YesNo.no )
       .Otherwise!(            void ) C;
    static assert(is(C == void));
}

unittest    // switch-case-otherwise over constant
{
    alias StaticSwitch!( 16 )
            .Case!( 16, int    )
            .Case!( 32, real   )
            .Case!( 64, string )
       .Otherwise!(     void   ) A;
    static assert(is(A == int));

    alias StaticSwitch!( 64 )
            .Case!( 16, int    )
            .Case!( 32, real   )
            .Case!( 64, string )
       .Otherwise!(     void   ) B;
    static assert(is(B == string));

    alias StaticSwitch!( 128 )
            .Case!( 16, int    )
            .Case!( 32, real   )
            .Case!( 64, string )
       .Otherwise!(     void   ) C;
    static assert(is(C == void));

    // Finish is disallowed
    static assert(!__traits(compiles,
            StaticSwitch!( 32 )
                .Case!( 16, int    )
                .Case!( 32, real   )
                .Case!( 64, string )
                .Finish ));
}

unittest    // switch-case-otherwise over symbol
{
    static int varA, varB, varC, varZ;

    alias StaticSwitch!( varA )
            .Case!( varA, int    )
            .Case!( varB, real   )
            .Case!( varC, string )
       .Otherwise!(       void   ) A;
    static assert(is(A == int));

    alias StaticSwitch!( varC )
            .Case!( varA, int    )
            .Case!( varB, real   )
            .Case!( varC, string )
       .Otherwise!(       void   ) B;
    static assert(is(B == string));

    alias StaticSwitch!( varZ )
            .Case!( varA, int    )
            .Case!( varB, real   )
            .Case!( varC, string )
       .Otherwise!(       void   ) Z;
    static assert(is(Z == void));

    // Finish is disallowed
    static assert(!__traits(compiles,
            StaticSwitch!( varB )
                .Case!( varA, int    )
                .Case!( varB, real   )
                .Case!( varC, string )
                .Finish ));
}

unittest    // result = constant value
{
    enum a = StaticSwitch!( "kilo" )
            .Case!( "kilo",     1_000 )
            .Case!( "mega", 1_000_000 )
       .Otherwise!(                -1 );
    static assert(a == 1_000);

    enum b = StaticSwitch!( "mega" )
            .Case!( "kilo",     1_000 )
            .Case!( "mega", 1_000_000 )
       .Otherwise!(                -1 );
    static assert(b == 1_000_000);

    enum c = StaticSwitch!( "giga" )
            .Case!( "kilo",     1_000 )
            .Case!( "mega", 1_000_000 )
       .Otherwise!(                -1 );
    static assert(c == -1);
}

unittest    // result = symbol
{
    static int varA, varB, varC;

    alias StaticSwitch!( "A" )
            .Case!( "A", varA )
            .Case!( "B", varB )
       .Otherwise!( "C", varC ) x;
    static assert(__traits(isSame, x, varA));

    alias StaticSwitch!( "B" )
            .Case!( "A", varA )
            .Case!( "B", varB )
       .Otherwise!( "C", varC ) y;
    static assert(__traits(isSame, y, varB));

    alias StaticSwitch!( "C" )
            .Case!( "A", varA )
            .Case!( "B", varB )
       .Otherwise!(      varC ) z;
    static assert(__traits(isSame, z, varC));
}


// NOTE: The following overload of StaticSwitch is almost identical to
//       the above one, except that the target is a type.

/**
 * ditto
 */
template StaticSwitch(Target, alias equal = isSame)
{
    // Install Case/Finish/Otherwise nodes.
    mixin GenerateNode!(Condition.init, SwitchState!Target);


    //----------------------------------------------------------------//
private:

    enum Condition
    {
        unmatched,
        matched,
    }


    template Pack(      T   ) { alias T unpack; }
    template Pack(alias s   ) { alias s unpack; }
//  template Pack(      t...) { alias t unpack; }


    // Update the state to reflect that 'Cast!(match, ...)' is consumed.
    template popCase(alias state, Match)
    {
        alias state.pop!(Match) popCase;

        static assert(!__traits(isSame, state, popCase),
                      "Invalid case: " ~ match.stringof);
    }


    // <unmatched>
    //     :
    //  .Case     !( cond, result )
    //  .Otherwise!(       result )
    //
    template GenerateNode(Condition condition : Condition.unmatched,
                          alias state)
    {
        template Case(Match, Result)
        {
            alias GenericCase_!(Match, Pack!Result) Case;
        }

        template Case(Match, alias result)
        {
            alias GenericCase_!(Match, Pack!result) Case;
        }

//      template Case(Match, result...)
//      {
//          alias GenericCase_!(Match, Pack!result) Case;
//      }


        // Using an Otherwise node under the unmatched state yields the
        // specified default value.
        template Otherwise(      Result   ) { alias Result Otherwise; }
        template Otherwise(alias result   ) { alias result Otherwise; }
//      template Otherwise(      result...) { alias result Otherwise; }


        // Recursively install Case/Finish/Otherwise nodes.
        private template GenericCase_(Match, alias result)
        {
            private alias popCase!(state, Match) nextState;

            static if (equal!(Target, Match))
                mixin GenerateNode!(Condition.matched, nextState, result);
            else
                mixin GenerateNode!(Condition.unmatched, nextState);
        }
    }


    // <matched>
    //     :
    //  .Case!( cond, result )
    //  .Finish
    //
    template GenerateNode(Condition condition : Condition.matched,
                          alias     state,
                          alias     result)
    {
        // Under the matched state Case just propagates the result.
        template Case(Match, _...)
        {
            mixin GenerateNode!(
                    condition, popCase!(state, Match), result);
        }


        // Otherwise yields the propagated result.
        template Otherwise(_...) { alias result.unpack Otherwise; }


        // Finish must not be exposed if there are uncaught cases.
        static if (state.finished) alias result.unpack Finish;
    }
}


unittest    // switch-case-otherwise over type
{
    static struct S {}
    static struct T {}
    static struct U {}
    static struct X {}

    alias StaticSwitch!( S )
            .Case!( S, int    )
            .Case!( T, real   )
            .Case!( U, string )
       .Otherwise!(    void   ) A;
    static assert(is(A == int));

    alias StaticSwitch!( U )
            .Case!( S, int    )
            .Case!( T, real   )
            .Case!( U, string )
       .Otherwise!(    void   ) B;
    static assert(is(B == string));

    alias StaticSwitch!( X )
            .Case!( S, int    )
            .Case!( T, real   )
            .Case!( U, string )
       .Otherwise!(    void   ) C;
    static assert(is(C == void));

    // Finish is disallowed
    static assert(!__traits(compiles,
            StaticSwitch!( T )
                .Case!( S, int    )
                .Case!( T, real   )
                .Case!( U, string )
                .Finish ));
}



//----------------------------------------------------------------------------//

// Supporting templates for tracking the state of a StaticSwitch instance.

private template SwitchState(alias target)
{
    static if (is(typeof(target) T) && is(T == enum))
        alias SwitchState_Enum!(T, EnumMembers!T) SwitchState;
    else
        alias SwitchState_Symbol!(target) SwitchState;
}

private template SwitchState(Target)
{
    alias SwitchState_Type!(Target) SwitchState;
}



// SwitchState for closed enums.  This state elaborately deals with the
// enum members and signals 'finished' when all the members are covered.
private template SwitchState_Enum(Enum, enumMembers...)
{
    enum finished = (enumMembers.length == 0);

    template pop(alias match)
    {
        alias SwitchState_Enum!(Enum, erase!(match)) pop;
    }

    private template erase(alias e, size_t i = 0)
    {
        static if (i < enumMembers.length)
        {
            static if (isSame!(enumMembers[i], e))
                // Mark it as 'already covered' by removing it.
                alias TypeTuple!(enumMembers[    0 .. i],
                                 enumMembers[i + 1 .. $]) erase;
            else
                alias erase!(e, i + 1) erase;
        }
        else
        {
            // No such member, or it's already covered.
            alias enumMembers erase;
        }
    }
}


// SwitchState for generic symbols and constants.
private template SwitchState_Symbol(alias symbol, popList...)
{
    enum finished = false;

    template pop(alias match)
    {
        alias SwitchState_Symbol!(symbol, append!(match)) pop;
    }

    private template append(alias e, size_t i = 0)
    {
        static if (i < popList.length)
        {
            static if (isSame!(popList[i], e))
                // The symbol is already covered!
                alias popList append;
            else
                alias append!(e, i + 1) append;
        }
        else
        {
            // Mark it as 'already covered' by appending to the list.
            alias TypeTuple!(popList, e) append;
        }
    }
}


// SwitchState for generic types.
private template SwitchState_Type(Type, popList...)
{
    enum finished = false;

    template pop(Match)
    {
        alias SwitchState_Type!(Type, append!(Match)) pop;
    }

    private template append(E, size_t i = 0)
    {
        static if (i < popList.length)
        {
            static if (is(popList[i] == E))
                // The type is already covered!
                alias popList append;
            else
                alias append!(E, i + 1) append;
        }
        else
        {
            // Mark it as 'already covered' by appending to the list.
            alias TypeTuple!(popList, E) append;
        }
    }
}



//----------------------------------------------------------------------------//
// Utilities
//----------------------------------------------------------------------------//


/**
 *
 */
template EnumMembers(Enum)
    if (is(Enum == enum))
{
    alias EnumSpecificMembers!(Enum, __traits(allMembers, Enum)) EnumMembers;
}


private template EnumSpecificMembers(Enum, idents...)
{
    static assert(is(Enum == enum));

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


