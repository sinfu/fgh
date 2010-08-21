/**
 * $(LINK http://github.com/sinfu/fgh/blob/master/fgh/meta.d)
 *
 * Macros:
 *  D = $(I $1)
 */
module fgh.meta;

import std.typetuple : TypeTuple;



//----------------------------------------------------------------------------//
// Sort
//----------------------------------------------------------------------------//


/**
 * Returns $(D items) arranged in the increasing order in terms of $(D less).
 *
 * Params:
 *  less  = Comparison template used as the $(D <) operator.  See the example
 *          below for more details.
 *  items = Compile-time entities to sort.  Every entities must be comparable
 *          with each other by the $(D less) template.
 *
 * Example:
 *  The following code sorts the sequence $(D (5, 1, 4, 2, 3)) with a custom
 *  less operator $(D myLess).
--------------------
// Comparison template takes two arguments and returns true if a < b.
template myLess(int a, int b)
{
    enum bool myLess = (a > b);
}

alias TypeTuple!(5, 1, 4, 2, 3) sequence;
alias StaticSort!(myLess, sequence) result;

// The result is arranged in the decreasing order since myLess is
// actually the greater-than operator.
static assert([ result ] == [ 5, 4, 3, 2, 1 ]);
--------------------
 */
template StaticSort(alias less, items...)
{
    alias MergeSort!(less, items).result StaticSort;
}


unittest
{
    alias StaticSort!(standardLess, 4, 1, 2, 3) a;
    static assert(MatchTuple!(a).With!(1, 2, 3, 4));

    alias StaticSort!(standardLess,    int.max, int.min, 0) b;
    static assert(MatchTuple!(b).With!(int.min, 0, int.max));
}

unittest    // redundant sort
{
    alias StaticSort!(standardLess) e;
    static assert(e.length == 0);

    alias StaticSort!(standardLess, 1) one;
    static assert( MatchTuple!(one).With!(1) );

    alias StaticSort!(standardLess, 1, 2, 3) sorted;
    static assert( MatchTuple!(sorted).With!(1, 2, 3) );

    alias StaticSort!(standardLess, 2, 2, 2, 2) same;
    static assert( MatchTuple!(same).With!(2, 2, 2, 2) );
}

unittest    // mixed int & real
{
    alias StaticSort!(standardLess, 17.5, -4, 3.0, 9) mix;
    static assert( MatchTuple!(mix).With!(-4, 3.0, 9, 17.5) );
}

unittest    // sorting strings
{
    alias StaticSort!(standardLess, "ghi", "abc", "def") str;
    static assert(MatchTuple!(str).With!("abc", "def", "ghi") );
}

unittest    // sorting types
{
    alias StaticSort!(heterogeneousLess,  int,  real, short) A;
    alias StaticSort!(heterogeneousLess, real, short,   int) B;

    static assert(  int.mangleof == "i");
    static assert( real.mangleof == "e");
    static assert(short.mangleof == "s");
    static assert(is(A == TypeTuple!(real, int, short)));
    static assert(is(B == TypeTuple!(real, int, short)));
}


// Used by StaticSort.

private template MergeSort(alias less, items...)
    if (items.length < 2)
{
    alias items result;
}

private template MergeSort(alias less, items...)
    if (items.length >= 2)
{
    template Merge(sortA...)
    {
        template With(sortB...)
        {
            static if (less!(sortA[0], sortB[0]))
            {
                alias TypeTuple!(sortA[0], Merge!(sortA[1 .. $])
                                           .With!(sortB        )) With;
            }
            else
            {
                alias TypeTuple!(sortB[0], Merge!(sortA        )
                                           .With!(sortB[1 .. $])) With;
            }
        }

        template With()
        {
            alias sortA With;
        }
    }

    template Merge()
    {
        template With(sortB...)
        {
            alias sortB With;
        }
    }

    alias Merge!(MergeSort!(less, items[  0 .. $/2]).result)
          .With!(MergeSort!(less, items[$/2 .. $  ]).result) result;
}



//----------------------------------------------------------------------------//
// Tiarg Comparators
//----------------------------------------------------------------------------//
// template      standardLess(items...);
// template heterogeneousLess(items...);
// template            isSame(items...);
//----------------------------------------------------------------------------//


/**
 * Compares compile-time constants $(D items...) with the built-in less
 * operator $(D <).  Values in $(D items...) must be comparable with each
 * other.
 *
 * Params:
 *  items = Compile-time constants or expressions to compare.  Instantiation
 *          fails if $(D items) contains only zero or one entity, or if it
 *          contains any non-comparable entities.
 *
 * Example:
 *  In the following code, a generic algorithm $(D TrimIncreasingPart) takes
 *  a comparator template $(D less) and performs certain operation on $(D seq).
 *  Here $(D standardLess) is used for the $(D less) argument.
--------------------
template TrimIncreasingPart(alias less, seq...)
{
    static if (seq.length >= 2 && less!(seq[0], seq[1]))
        alias TrimIncreasingPart!(less, seq[1 .. $]) TrimIncreasingPart;
    else
        alias                           seq          TrimIncreasingPart;
}

// Remove the first increasing part (0, 1, 2) of the original sequence.
alias TypeTuple!(0, 1, 2, 3.5, 2, 1) sequence;
alias TrimIncreasingPart!(standardLess, sequence) result;

// The result is (3.5, 2, 1).
static assert([ result ] == [ 3.5, 2, 1 ]);
--------------------
 */
template standardLess(items...)
{
    static assert(items.length >= 2);

    static if (items.length > 2)
    {
        enum bool standardLess = standardLess!(items[0 .. 2]) &&
                                 standardLess!(items[1 .. $]);
    }
    else
    {
        // NOTE: Use static this so the expression is evaluated right now.

        static if (items[0] < items[1])
            enum bool standardLess =  true;
        else
            enum bool standardLess = false;
    }
}


unittest
{
    static assert( standardLess!(1, 2));
    static assert( standardLess!(1, 2, 3, 4, 5));
    static assert(!standardLess!(2, 1));
    static assert(!standardLess!(5, 4, 3, 2, 1));
    static assert(!standardLess!(1, 2, 3, 5, 4));
    static assert(!standardLess!(1, 2, 4, 3, 5));
}

unittest    // mixed types and strings
{
    static assert( standardLess!(-1, -0.5, -0.1L));
    static assert(!standardLess!( 1,  0.5,  0.1L));
    static assert( standardLess!("A", "B", "C"));
    static assert(!standardLess!("c", "b", "a"));
}

unittest    // errors
{
    static assert(!__traits(compiles, standardLess!()));
    static assert(!__traits(compiles, standardLess!(1)));
    static assert(!__traits(compiles, standardLess!(123, "45")));
    static assert(!__traits(compiles, standardLess!(int, char)));
    static assert(!__traits(compiles, standardLess!(123, char)));
    static assert(!__traits(compiles, standardLess!(123, standardLess)));
}



/**
 * Compares compile-time entities $(D items...) by their mangled name.
 * The tuple $(D items) can consist of any kind of compile-time entities
 * (unlike the restrictive $(D standardLess) template).
 *
 * The point of this template is to allow comparison against types and
 * symbols so that tuples of such kind of entities can be normalized by
 * sorting.  See the example below.
 *
 * Note that the result of comparison may be counter-intuitive since mangled
 * names are used.  For example, $(D heterogeneousLess!(-1, 1)) evaluates to
 * $(D false) whereas -1 is mathematically less than 1.  This is because the
 * mangled names for -1 and 1 are "ViN1" and "Vi1" respectively.
 *
 * Params:
 *  items = Two or more compile time entities of any kind.
 *
 * Returns:
 *  $(D true) if and only if $(D items[0] < ... < items[$ - 1]) in terms of
 *  their mangled names.  Returns $(D false) otherwise.
 *
 * Example:
 *  The following example sorts type tuple with $(D StaticSort) and
 *  $(D heterogeneousLess).
--------------------
alias StaticSort!(heterogeneousLess,  int,  real, short) A;
alias StaticSort!(heterogeneousLess, real, short,   int) B;

// The two type tuples are sorted (or normalized).
static assert(is(A == TypeTuple!(real, int, short)));
static assert(is(B == TypeTuple!(real, int, short)));
--------------------
 */
template heterogeneousLess(items...)
{
    static assert(items.length >= 2);

    static if (items.length > 2)
        enum bool heterogeneousLess = heterogeneousLess!(items[0 .. 2]) &&
                                      heterogeneousLess!(items[1 .. $]);
    else
        enum bool heterogeneousLess = (Id!(items[0]) < Id!(items[1]));
}


// Returns the mangled name of entities.
private template Id(entities...)
{
    // TODO: optimize
    enum string Id = Entity!(entities).ToType.mangleof;
}


// Helper template for obtaining the mangled name of entities.
private template Entity(entities...)
{
    struct ToType {}
}


unittest    // integers
{
    static assert( heterogeneousLess!(1, 2));
    static assert(!heterogeneousLess!(2, 1));
    static assert( heterogeneousLess!(1, 2, 3, 4));
    static assert(!heterogeneousLess!(1, 3, 2, 4));
    static assert(!heterogeneousLess!(-1,  1));
    static assert( heterogeneousLess!( 1, -1));
}

unittest    // types
{
    static assert(char.mangleof == "a");
    static assert(real.mangleof == "e");
    static assert( int.mangleof == "i");
    static assert(bool.mangleof == "b");
    static assert( heterogeneousLess!(char, real,  int));
    static assert(!heterogeneousLess!(bool, real, char));

    struct A {}
    struct B {}
    struct C {}
    static assert( heterogeneousLess!(A, B));
    static assert( heterogeneousLess!(B, C));
    static assert( heterogeneousLess!(A, B, C));
    static assert(!heterogeneousLess!(B, C, A));
}

unittest    // symbols
{
    static assert( heterogeneousLess!(standardLess, heterogeneousLess));
    static assert(!heterogeneousLess!(standardLess, int));
}



// Helper templates for isSame!(...) below.

private template isSame_(A, B)
{
    enum isSame_ = is(A == B);
}

private template isSame_(alias a, alias b)
{
    static if (__traits(compiles, interpretNow!(bool, a == b)))
    {
        enum isSame_ = is(typeof(a) == typeof(b)) && a == b;
    }
    else
    {
        enum isSame_ = __traits(isSame, a, b);
    }
}

private template isSame_(items...)
    if (items.length == 2)
{
    enum isSame_ = is(Entity!(items[0]).ToType ==
                      Entity!(items[1]).ToType);
}


/**
 * Returns $(D true) if a tuple $(D items...) is composed of same entity.
 *
 * Params:
 *  items = Any compile-time entities: types, constants and/or symbols.
 *
 * Returns:
 *  $(D true) if $(D items...) are all the same entity, or $(D false)
 *  otherwise.
 *
 * Example:
 *  $(D FrontUniq) in the following code uses $(D isSame) for seeing if
 *  preceding two items in $(D seq) are identical or not.
--------------------
template FrontUniq(seq...)
{
    static if (seq.length >= 2 && isSame!(seq[0], seq[1]))
        alias FrontUniq!(seq[1 .. $]) FrontUniq;
    else
        alias seq FrontUniq;
}

alias FrontUniq!(int, int, int, real, string) Result;
static assert(is(Result == TypeTuple!(int, real, string)));
--------------------
 */
template isSame(items...)
    if (items.length >= 1)
{
    static if (items.length > 1)
    {
        static if (isSame_!(items[0 .. 2]))
            enum isSame = isSame!(items[1 .. $]);
        else
            enum isSame = false;
    }
    else
    {
        enum isSame = true; // isSame(x) == true for all x
    }
}


unittest    // always true for single argument
{
    struct S {}
    static assert(isSame!(1));
    static assert(isSame!(int));
    static assert(isSame!(S));
    static assert(isSame!(isSame));
}

unittest    // two identical entitites
{
    struct S
    {
        static void fun() {}
    }
    static assert(isSame!(1, 1));
    static assert(isSame!("dee", "dee"));
    static assert(isSame!(int, int));
    static assert(isSame!(S, S));
    static assert(isSame!(S.fun, S.fun));
}

unittest    // two different entities
{
    struct U
    {
        static void fun() {}
        static void gun() {}
    }
    struct V {}
    static assert(!isSame!(1, 2));
    static assert(!isSame!(1, 1.0));
    static assert(!isSame!("dee", "Dee"));
    static assert(!isSame!(U, V));
    static assert(!isSame!(U.fun, U.gun));
}

unittest    // mismatched entity types
{
    static assert(!isSame!(1, "string"));
    static assert(!isSame!(int, 42));
    static assert(!isSame!(isSame, real));
}

unittest    // constant & non-constant symbols
{
    static immutable constA = 1;
    static immutable constB = "string";
    static assert( isSame!(constA, constA));
    static assert(!isSame!(constA, constB));
    static assert( isSame!(constB, constB));
    static assert(!isSame!(constB, constA));

    static int varA;
    static int varB;
    static assert( isSame!(varA, varA));
    static assert(!isSame!(varA, varB));
}

unittest    // alias
{
    alias int  Counter;
    alias real Value;
    static assert( isSame!(Counter, Counter));
    static assert( isSame!(Counter,     int));
    static assert( isSame!(    int, Counter));
    static assert(!isSame!(Counter,   Value));

    static int varA, varB;
    alias varA store;
    static assert( isSame!(store, store));
    static assert( isSame!(store,  varA));
    static assert(!isSame!(store,  varB));
}

unittest    // compare three or more entities
{
    static assert( isSame!(1, 1, 1, 1));
    static assert(!isSame!(0, 1, 1, 1));
    static assert(!isSame!(1, 0, 1, 1));
    static assert(!isSame!(1, 1, 0, 1));
    static assert(!isSame!(1, 1, 1, 0));
    static assert(!isSame!(1, 1, 1, int));
}



//----------------------------------------------------------------------------//
// template StaticSetIntersection       (A, B, less)
// template StaticSetUnion              (A, B, less)
// template StaticSetDifference         (A, B, less)
// template StaticSetSymmetricDifference(A, B, less)
//
// template StaticUniq                  (items...)
//----------------------------------------------------------------------------//


version (unittest)
private template Pack(items...)
{
    enum bool empty = (items.length == 0);
    alias items elements;
}


// Adaptively selects the appropriate comparison template for A.
private template adaptiveLess(alias A)
{
    static if (__traits(hasMember, A, "ordering"))
    {
        alias A.ordering adaptiveLess;
    }
    else static if (__traits(compiles, standardLess!(A.elements)))
    {
        alias standardLess adaptiveLess;
    }
    else
    {
        alias heterogeneousLess adaptiveLess;
    }
}


/**
 * Constructs a sorted static tuple consisting of the set intersection of the
 * two sorted static containers $(D A) and $(D B).
 *
 * If $(D A) and $(D B) contains $(D m) and $(D n) duplicates of the same
 * element respectively, the resulting union will contain $(D min(m,n))
 * duplicates.
 *
 * Params:
 *     A = Static container whose elements ($(D A.elements)) are sorted in
 *         terms of $(D less).
 *     B = ditto.
 *  less = Comparison template function. This argument is automatically chosen
 *         if not specified.
 *
 * Returns:
 *  Static tuple consisting of the intersection of $(D A) and $(D B).
 *
 * Example:
 *  Computing the intersection of two sorted lists.
--------------------
alias StaticList!(2, 3, 5, 7) primes;
alias StaticList!(1, 3, 5, 7) odds;

alias StaticSetUnion!(primes, odds) oddPrimes;
static assert([ oddPrimes ] == [ 3, 5, 7 ]);
--------------------
 */
template StaticSetIntersection(
        alias A, alias B, alias less = adaptiveLess!(A))
{
    alias StaticSetIntersectionImpl!(less)
         .Intersection!(A.elements)
                 .With!(B.elements)     StaticSetIntersection;
}

private template StaticSetIntersectionImpl(alias less)
{
    template Intersection()
    {
        template With(B...)
        {
            alias TypeTuple!() With;
        }
    }

    template Intersection(A...)
    {
        template With()
        {
            alias TypeTuple!() With;
        }

        template With(B...)
        {
            static if (less!(A[0], B[0]))
            {
                alias Intersection!(A[1 .. $]).With!(B) With;
            }
            else static if (less!(B[0], A[0]))
            {
                alias Intersection!(A).With!(B[1 .. $]) With;
            }
            else
            {
                alias TypeTuple!(A[0], Intersection!(A[1 .. $])
                                              .With!(B[1 .. $])) With;
            }
        }
    }
}


unittest
{
    alias StaticSetIntersection!(Pack!(1, 1, 2, 3, 5),
                                 Pack!(1, 3, 5, 7, 9)) A;
    static assert(MatchTuple!(A).With!(1, 3, 5));

    alias StaticSetIntersection!(Pack!("abc", "def", "ghi"),
                                 Pack!("123", "abc", "xyz")) B;
    static assert(MatchTuple!(B).With!("abc"));
}

unittest    // empty intersection
{
    alias StaticSetIntersection!(Pack!(1, 3, 5, 7, 9),
                                 Pack!(0, 2, 4, 6, 8)) A;
    static assert(A.length == 0);
}

unittest    // empty \cap sth
{
    alias StaticSetIntersection!(Pack!(), Pack!(1, 2, 3)) A;
    static assert(A.length == 0);

    alias StaticSetIntersection!(Pack!(1, 2, 3), Pack!()) B;
    static assert(B.length == 0);

    alias StaticSetIntersection!(Pack!(), Pack!()) C;
    static assert(C.length == 0);
}

unittest    // duplicate elements
{
    alias StaticSetIntersection!(Pack!(1, 1, 1, 2, 2, 2),
                                 Pack!(1, 2, 2, 3, 4, 5)) A;
    static assert(MatchTuple!(A).With!(1, 2, 2));

    alias StaticSetIntersection!(Pack!(1, 2, 2, 3, 4, 5),
                                 Pack!(1, 1, 1, 2, 2, 2)) B;
    static assert(MatchTuple!(B).With!(1, 2, 2));
}



/**
 * Constructs a sorted static tuple consisting of the set union of the two
 * sorted static containers $(D A) and $(D B).
 *
 * If $(D A) and $(D B) contains $(D m) and $(D n) duplicates of the same
 * element respectively, the resulting union will contain $(D max(m,n))
 * duplicates.
 *
 * Params:
 *     A = Static container whose elements ($(D A.elements)) are sorted in
 *         terms of $(D less).
 *     B = ditto.
 *  less = Comparison template function. This argument is automatically chosen
 *         if not specified.
 *
 * Returns:
 *  Static tuple consisting of the union of $(D A) and $(D B).
 *
 * Example:
 *  Union of the first four primes and the first four odd numbers.
--------------------
alias StaticList!(2, 3, 5, 7) primes;
alias StaticList!(1, 3, 5, 7) odds;

alias StaticSetUnion!(primes, odds) primesAndOdds;
static assert([ primesAndOdds ] == [ 1, 2, 3, 5, 7 ]);
--------------------
 */
template StaticSetUnion(
        alias A, alias B, alias less = adaptiveLess!(A))
{
    alias StaticSetUnionImpl!(less)
            .Union!(A.elements)
             .With!(B.elements)     StaticSetUnion;
}

private template StaticSetUnionImpl(alias less)
{
    template Union()
    {
        template With(B...)
        {
            alias B With;
        }
    }

    template Union(A...)
    {
        template With()
        {
            alias A With;
        }

        template With(B...)
        {
            static if (less!(A[0], B[0]))
            {
                alias TypeTuple!(A[0], Union!(A[1 .. $])
                                       .With!(B[0 .. $])) With;
            }
            else static if (less!(B[0], A[0]))
            {
                alias TypeTuple!(B[0], Union!(A[0 .. $])
                                       .With!(B[1 .. $])) With;
            }
            else
            {
                alias TypeTuple!(A[0], Union!(A[1 .. $])
                                       .With!(B[1 .. $])) With;
            }
        }
    }
}


unittest
{
    alias StaticSetUnion!(Pack!(1, 1, 3, 5, 8),
                          Pack!(1, 3, 5, 7, 9)) A;
    static assert(MatchTuple!(A).With!(1, 1, 3, 5, 7, 8, 9));

    alias StaticSetUnion!(Pack!("abc", "def", "ghi"),
                          Pack!("def", "ghi", "jkl")) B;
    static assert(MatchTuple!(B).With!("abc", "def", "ghi", "jkl"));
}

unittest    // empty \cup sth
{
    alias Pack!() E;
    alias Pack!(1, 2, 3, 4) A;

    alias StaticSetUnion!(E, A) K;
    static assert(MatchTuple!(K).With!(A.elements));

    alias StaticSetUnion!(A, E) L;
    static assert(MatchTuple!(L).With!(A.elements));

    alias StaticSetUnion!(E, E) M;
    static assert(MatchTuple!(M).With!(E.elements));
}

unittest    // duplicate elements
{
    alias StaticSetUnion!(Pack!(1, 1, 1, 2, 2, 2),
                          Pack!(1, 2, 2, 3, 4, 5)) A;
    static assert(MatchTuple!(A).With!(1, 1, 1, 2, 2, 2, 3, 4, 5));

    alias StaticSetUnion!(Pack!(1, 2, 2, 3, 4, 5),
                          Pack!(1, 1, 1, 2, 2, 2)) B;
    static assert(MatchTuple!(B).With!(1, 1, 1, 2, 2, 2, 3, 4, 5));
}



/**
 * Constructs a sorted static tuple consisting of the set difference of $(D A)
 * with respect to $(D B).
 *
 * Params:
 *     A = Static container whose elements ($(D A.elements)) are sorted in
 *         terms of $(D less).
 *     B = ditto.
 *  less = Comparison template function. This argument is automatically chosen
 *         if not specified.
 *
 * Returns:
 *  Static tuple consisting of the set difference of $(D A) with respect to
 *  $(D B).
 *
 * Example:
 *  { 5,15,25 } is only contained in $(D A), so the difference of $(D A)
 *  with respect to $(D B) is { 5,15,25 }.
--------------------
alias StaticList!( 5, 10, 15, 20, 25) A;
alias StaticList!(10, 20, 30, 40, 50) B;

alias StaticSetDifference!(A, B) diff;
static assert([ diff ] == [ 5, 15, 25 ]);
--------------------
 */
template StaticSetDifference(
        alias A, alias B, alias less = adaptiveLess!(A))
{
    alias StaticSetDifferenceImpl!(less)
            .Difference!(A.elements)
                    .To!(B.elements)    StaticSetDifference;
}

private template StaticSetDifferenceImpl(alias less)
{
    template Difference()
    {
        template To(B...)
        {
            alias TypeTuple!() To;
        }
    }

    template Difference(A...)
    {
        template To()
        {
            alias A To;
        }

        template To(B...)
        {
            static if (less!(A[0], B[0]))
            {
                alias TypeTuple!(A[0], Difference!(A[1 .. $])
                                              .To!(B[0 .. $])) To;
            }
            else static if (less!(B[0], A[0]))
            {
                alias Difference!(A[0 .. $]).To!(B[1 .. $]) To;
            }
            else
            {
                alias Difference!(A[1 .. $]).To!(B[1 .. $]) To;
            }
        }
    }
}


unittest
{
    alias StaticSetDifference!(Pack!(1, 1, 2, 3, 5),
                               Pack!(1, 3, 5, 7, 9)) A;
    static assert(MatchTuple!(A).With!(1, 2));

    alias StaticSetDifference!(Pack!("abc", "def", "ghi"),
                               Pack!("def", "ghi", "jkl")) B;
    static assert(MatchTuple!(B).With!("abc"));
}

unittest    // empty
{
    alias StaticSetDifference!(Pack!(), Pack!(1, 2, 3, 4)) A;
    static assert(A.length == 0);

    alias StaticSetDifference!(Pack!(1, 2, 3, 4), Pack!()) B;
    static assert(MatchTuple!(B).With!(1, 2, 3, 4));

    alias StaticSetDifference!(Pack!(), Pack!()) C;
    static assert(C.length == 0);
}

unittest    // duplicate elements
{
    alias StaticSetDifference!(Pack!(1, 1, 1, 2, 2, 2),
                               Pack!(      1,       2)) A;
    static assert(MatchTuple!(A).With!(1, 1, 2, 2));

    alias StaticSetDifference!(Pack!(1, 1, 1, 2, 2, 2),
                               Pack!(1, 1, 1, 1, 2, 2)) B;
    static assert(MatchTuple!(B).With!(2));

    alias StaticSetDifference!(Pack!(1, 2, 3, 4, 5, 6),
                               Pack!(1, 1, 1, 2, 2, 2)) C;
    static assert(MatchTuple!(C).With!(3, 4, 5, 6));
}



/**
 * Constructs a sorted static tuple consisting of the set symmetric difference
 * (or the XOR) of two sorted ranges $(D A) and $(D B).
 *
 * Params:
 *     A = Static container whose elements ($(D A.elements)) are sorted in
 *         terms of $(D less).
 *     B = ditto.
 *  less = Comparison template function. This argument is automatically chosen
 *         if not specified.
 *
 * Returns:
 *  Static tuple consisting of the set symmetric difference of $(D A) and
 *  $(D B).
 *
 * Example:
 *  The common element $(D int) does not appear in the result.
--------------------
alias StaticList!(bool, int, void*) Scalars;
alias StaticList!(byte, int, short) Integers;
alias StaticSetSymmetricDifference!(Scalars, Integers) Result;

static assert(is(Result == TypeTuple!(bool, byte, short, void*)));
--------------------
 */
template StaticSetSymmetricDifference(
        alias A, alias B, alias less = adaptiveLess!(A))
{
    alias StaticSetSymmetricDifferenceImpl!(less)
            .Difference!(A.elements)
                  .With!(B.elements)    StaticSetSymmetricDifference;
}

private template StaticSetSymmetricDifferenceImpl(alias less)
{
    template Difference()
    {
        template With(B...)
        {
            alias B With;
        }
    }

    template Difference(A...)
    {
        template With()
        {
            alias A With;
        }

        template With(B...)
        {
            static if (less!(A[0], B[0]))
            {
                alias TypeTuple!(A[0], Difference!(A[1 .. $])
                                            .With!(B[0 .. $])) With;
            }
            else static if (less!(B[0], A[0]))
            {
                alias TypeTuple!(B[0], Difference!(A[0 .. $])
                                            .With!(B[1 .. $])) With;
            }
            else
            {
                alias Difference!(A[1 .. $]).With!(B[1 .. $]) With;
            }
        }
    }
}


unittest
{
    alias StaticSetSymmetricDifference!(
            Pack!(1, 1, 2, 3, 5),
            Pack!(1, 3, 5, 7, 9)) A;
    static assert(MatchTuple!(A).With!(1, 2, 7, 9));

    alias StaticSetSymmetricDifference!(
            Pack!(1, 3, 5, 7, 9),
            Pack!(1, 1, 2, 3, 5)) revA;
    static assert(MatchTuple!(revA).With!(1, 2, 7, 9));

    alias StaticSetSymmetricDifference!(
            Pack!("abc", "def", "ghi"),
            Pack!("def", "ghi", "jkl")) B;
    static assert(MatchTuple!(B).With!("abc", "jkl"));
}

unittest    // empty
{
    alias StaticSetSymmetricDifference!(
            Pack!(), Pack!(1, 2, 3, 4)) A;
    static assert(MatchTuple!(A).With!(1, 2, 3, 4));

    alias StaticSetSymmetricDifference!(
            Pack!(1, 2, 3, 4), Pack!()) B;
    static assert(MatchTuple!(B).With!(1, 2, 3, 4));

    alias StaticSetSymmetricDifference!(Pack!(), Pack!()) C;
    static assert(C.length == 0);
}

unittest    // duplicate elements
{
    alias StaticSetSymmetricDifference!(
            Pack!(1, 1, 1, 2, 2, 2), Pack!(1, 2, 3, 4, 5)) A;
    static assert(MatchTuple!(A).With!(1, 1, 2, 2, 3, 4, 5));

    alias StaticSetSymmetricDifference!(
            Pack!(1, 2, 3, 4, 5), Pack!(1, 1, 1, 2, 2, 2)) revA;
    static assert(MatchTuple!(revA).With!(1, 1, 2, 2, 3, 4, 5));

    alias StaticSetSymmetricDifference!(
            Pack!(1, 1, 1, 2, 2, 2), Pack!(2, 2, 2, 3, 3)) B;
    static assert(MatchTuple!(B).With!(1, 1, 1, 3, 3));
}



/**
 * Removes any consecutive group of duplicate elements in $(D items) except
 * the first element of each group.
 *
 * Params:
 *  items = Tuple of zero or more compile-time entities.
 *
 * Returns:
 *  $(D items) without any consecutive duplicate elements.
 *
 * Example:
--------------------
alias StaticUniq!(1, 2, 3, 3, 4, 4, 4, 2, 2) uniq;
static assert(MatchTuple!(uniq).With!(1, 2, 3, 4, 2));
--------------------
 */
template StaticUniq(items...)
{
    static if (items.length > 1)
    {
        static if (isSame!(items[0], items[1]))
            alias            StaticUniq!(items[1 .. $])  StaticUniq;
        else
            alias TypeTuple!(items[0],
                             StaticUniq!(items[1 .. $])) StaticUniq;
    }
    else
    {
        alias items StaticUniq;
    }
}

unittest
{
    alias StaticUniq!(       ) uniq___;
    alias StaticUniq!(1      ) uniq1__;
    alias StaticUniq!(1, 2, 3) uniq123;
    alias StaticUniq!(1, 1, 1) uniq111;
    alias StaticUniq!(1, 1, 2) uniq112;
    alias StaticUniq!(1, 2, 2) uniq122;
    alias StaticUniq!(1, 2, 1) uniq121;

    static assert(uniq___.length == 0);
    static assert(uniq1__.length == 1);
    static assert(uniq123.length == 3);
    static assert(uniq111.length == 1);
    static assert(uniq112.length == 2);
    static assert(uniq122.length == 2);
    static assert(uniq121.length == 3);

    static assert([ uniq1__ ] == [ 1       ]);
    static assert([ uniq123 ] == [ 1, 2, 3 ]);
    static assert([ uniq111 ] == [ 1       ]);
    static assert([ uniq112 ] == [ 1,    2 ]);
    static assert([ uniq122 ] == [ 1, 2    ]);
    static assert([ uniq121 ] == [ 1, 2, 1 ]);
}



//----------------------------------------------------------------------------//
// Static List ?    (std.typelist)
//----------------------------------------------------------------------------//

template StaticList(items...)
{
    enum empty  = (items.length == 0);
    enum length = items.length;
    alias items elements;

    static if (items.length > 0)
    {
        alias StaticList!(items[1 .. $]) tail;
    }
}



//----------------------------------------------------------------------------//
// Static Set
//----------------------------------------------------------------------------//
// template StaticSet(items...)
// {
//     enum bool   empty;
//     enum size_t length;
//     alias       elements;
//     alias       ordering;
//
//     template    equals   (rhs);
//     template    contains (rhs);
//
//     template    add      (items);
//     template    remove   (items);
//
//     template    intersection        (rhs);
//     template    union_              (rhs);
//     template    difference          (rhs);
//     template    symmetricDifference (rhs);
// }
//
// template isStaticSet(set);
//----------------------------------------------------------------------------//


// For detecting StaticSet instances. (Used by isStaticSet far below...)
private struct StaticSetTag {}


/**
 * $(D StaticSet) is a collection of compile-time entities (types, symbols
 * and/or constants) without regard to order or duplicates.
 *
 * Example:
 *  The following code instantiates three $(D StaticSet)s with the same
 *  types in different ordering, and compares them for equality.
--------------------
alias StaticSet!(      int,   real, string) A;
alias StaticSet!( int, int,   real, string) B;
alias StaticSet!(real, int, string,   real) C;

// Compare the sets for equality without regard to order or duplicates.
static assert(A.equals!(B));
static assert(A.equals!(C));
static assert(A.equals!(string, real, int));

// The three instances even share the same symbol.
static assert(__traits(isSame, A, B));
static assert(__traits(isSame, B, C));
static assert(__traits(isSame, C, A));
--------------------
 */
template StaticSet(items...)
    if (isSetElementsNormalized!(items))
{
private:
    alias StaticSetTag      ContainerTag;   // for isStaticSet
    alias StaticSet!(items) This;           // reference to itself

    static assert(isStaticSet!(This));


public:
    //----------------------------------------------------------------//
    // Properties
    //----------------------------------------------------------------//


    /**
     * Returns $(D true) if and only if the set is _empty.
     */
    enum bool empty = (items.length == 0);


    /**
     * The number of unique elements in the set.
     */
    enum size_t length = items.length;


    /**
     * The _elements in the set.
     */
    alias items elements;


    /**
     * The _ordering template used for normalizing the order of the
     * elements in this set.
     */
    alias staticSetOrdering ordering;



    //----------------------------------------------------------------//
    // Set Comparison
    //----------------------------------------------------------------//


    /**
     * Compares the set with $(D rhs) for equality.
     *
     * Params:
     *  rhs = $(D StaticSet) instance or an immediate tuple to compare.
     *
     * Returns:
     *  $(D true) if the two sets are the same, or $(D false) otherwise.
     *
     * Example:
--------------------
alias StaticSet!(1, 2, "abc") A;

static assert(A.equals!(A));
static assert(A.equals!("abc", 1, 2, 1));
--------------------
     */
    template equals(alias rhs)
        if (isStaticSet!(rhs))
    {
        // Template instances have the same symbol if and only if they
        // are instantiated with the same arguments.

        enum equals = __traits(isSame, This, rhs);
    }


    /// ditto
    template equals(rhs...)
    {
        enum equals = equals!(StaticSet!(rhs));
    }


    unittest
    {
        static assert(equals!(This));
        static assert(equals!(elements));
    }



    /**
     * Determines if $(D rhs) is a subset of this set.
     *
     * Params:
     *  rhs = $(D StaticSet) instance or an immediate tuple to compare.
     *
     * Returns:
     *  $(D true) if $(D rhs) is a subset of this set, or $(D false) otherwise.
     *
     * Example:
--------------------
alias StaticSet!(1, 2, "abc") A;
alias StaticSet!(1, 2       ) B;

static assert(A.contains!(A));
static assert(A.contains!(B));
static assert(A.contains!(2, "abc"));
--------------------
     */
    template contains(alias rhs)
        if (isStaticSet!(rhs))
    {
        // Compare with the union for equality.
        enum contains = StaticSet!(elements, rhs.elements).equals!(This);
    }


    /// ditto
    template contains(rhs...)
    {
        enum contains = StaticSet!(elements, rhs).equals!(This);
    }


    unittest
    {
        static assert(contains!(This));
        static assert(contains!(elements));
        static assert(contains!( StaticSet!() ));
    }



    //----------------------------------------------------------------//
    // Container Operations
    //----------------------------------------------------------------//


    /**
     * Returns the union of this set and $(D {items...}).
     *
     * Params:
     *  items = Compile-time entities to _add to the set.  Note that sets
     *          ($(D StaticSet) instances) in $(D items) are never expanded
     *          and the symbols of the sets itselves are added.  In such a
     *          case, the resulting set will be a set of sets.
     *
     * Returns:
     *  $(D StaticSet) that is the union of this set and $(D {items}).
     *
     * Examples:
     *  Appending the value $(D 4) two times to the set $(D A).
--------------------
alias StaticSet!(1, 2, 3) A;

alias A.add!(4) B;  // The new item '4' is added.
alias B.add!(4) C;  // No effect.

static assert(B.equals!(1, 2, 3, 4));
static assert(C.equals!(1, 2, 3, 4));
--------------------
     *
     *  Set of sets.
--------------------
alias StaticSet!() zero;
alias zero.add!(zero) one;
alias  one.add!( one) two;
alias  two.add!( two) three;

static assert(three.length == 3);
static assert(three.equals!(zero, one, two));
--------------------
     */
    template add(items...)
    {
        alias union_!(items) add;
    }


    unittest
    {
        static assert(add!(elements).equals!(This));
    }



    /**
     * Returns the difference of this set and $(D {items...}).
     *
     * Params:
     *  items = Compile-time entities to _remove from the set.  This argument
     *          may contain _items that is not contained in the set; such
     *          _items are simply ignored.
     *
     * Returns:
     *  $(D StaticSet) that is the difference of this set and $(D {items}).
     *
     * Example:
     *  Removing $(D byte) and $(D ubyte) from the set of the built-in signed
     *  integral types.  $(D ubyte) is just ignored and the resulting set
     *  consisting of $(D short), $(D int) and $(D long).
--------------------
alias StaticSet!(byte, short, int, long) Signed;
alias Signed.remove!(byte, ubyte) Longer;

static assert(Longer.equals!(short, int, long));
--------------------
     */
    template remove(items...)
    {
        alias difference!(items) remove;
    }


    unittest
    {
        static assert(remove!(elements).equals!());
    }



    //----------------------------------------------------------------//
    // Set Operations
    //----------------------------------------------------------------//


    /**
     * Constructs the set _intersection of this set and $(D rhs).
     *
     * Params:
     *  rhs = $(D StaticSet) instance or an immediate tuple.
     *
     * Returns:
     *  $(D StaticSet) that is composed of the common elements in this
     *  set and $(D rhs).
     *
     * See_Also:
     *  $(D StaticSetIntersection)
     */
    template intersection(alias rhs)
        if (isStaticSet!(rhs))
    {
        alias StaticSet!(StaticSetIntersection!(This, rhs)) intersection;
    }


    /// ditto
    template intersection(rhs...)
    {
        alias intersection!(StaticSet!(rhs)) intersection;
    }


    unittest
    {
        static assert(intersection!(This    ).equals!(This));
        static assert(intersection!(elements).equals!(This));

        alias StaticSet!() zero;
        static assert(intersection!(zero).equals!(zero));
        static assert(intersection!(    ).equals!(zero));
    }



    /**
     * Constructs the set union of this set and $(D rhs).
     *
     * Params:
     *  rhs = $(D StaticSet) instance or an immediate tuple.
     *
     * Returns:
     *  $(D StaticSet) that is composed of the elements in this set and/or
     *  $(D rhs).
     *
     * See_Also:
     *  $(D StaticSetUnion), $(D StaticSet.add)
     */
    template union_(alias rhs)
        if (isStaticSet!(rhs))
    {
        alias StaticSet!(StaticSetUnion!(This, rhs)) union_;
    }


    /// ditto
    template union_(rhs...)
    {
        alias union_!(StaticSet!(rhs)) union_;
    }


    unittest
    {
        static assert(union_!(This    ).equals!(This));
        static assert(union_!(elements).equals!(This));

        alias StaticSet!() zero;
        static assert(union_!(zero).equals!(This));
        static assert(union_!(    ).equals!(This));
    }



    /**
     * Constructs the set _difference of this set with regard to $(D rhs).
     *
     * Params:
     *  rhs = $(D StaticSet) instance or an immediate tuple.
     *
     * Returns:
     *  $(D StaticSet) that is composed of the elements in this set except
     *  ones in $(D rhs).
     *
     * See_Also:
     *  $(D StaticSetDifference), $(D StaticSet.remove)
     */
    template difference(alias rhs)
        if (isStaticSet!(rhs))
    {
        alias StaticSet!(StaticSetDifference!(This, rhs)) difference;
    }


    /// ditto
    template difference(rhs...)
    {
        alias difference!(StaticSet!(rhs)) difference;
    }


    unittest
    {
        alias StaticSet!() zero;
        static assert(difference!(This    ).equals!(zero));
        static assert(difference!(elements).equals!(zero));
        static assert(difference!(zero    ).equals!(This));
        static assert(difference!(        ).equals!(This));
    }



    /**
     * Constructs the set symmetric difference of this set and $(D rhs).
     *
     * Params:
     *  rhs = $(D StaticSet) instance or an immediate tuple.
     *
     * Returns:
     *  $(D StaticSet) that is composed of the elements in this set and/or
     *  $(D rhs) except the common ones.
     *
     * See_Also:
     *  $(D StaticSetSymmetricDifference)
     */
    template symmetricDifference(alias rhs)
        if (isStaticSet!(rhs))
    {
        alias StaticSet!(StaticSetSymmetricDifference!(This, rhs))
                    symmetricDifference;
    }


    /// ditto
    template symmetricDifference(rhs...)
    {
        alias symmetricDifference!(StaticSet!(rhs)) symmetricDifference;
    }


    unittest
    {
        alias StaticSet!() zero;
        static assert(symmetricDifference!(This    ).equals!(zero));
        static assert(symmetricDifference!(elements).equals!(zero));
        static assert(symmetricDifference!(zero    ).equals!(This));
        static assert(symmetricDifference!(        ).equals!(This));
    }
}


unittest    // zero or single element
{
    alias StaticSet!() E;
    static assert(E.empty);
    static assert(E.length == 0);
    static assert(E.elements.length == 0);

    alias StaticSet!(int) T;
    static assert(!T.empty);
    static assert( T.length == 1);
    static assert( MatchTuple!(T.elements).With!(int) );

    alias StaticSet!(1) V;
    static assert(!V.empty);
    static assert( V.length == 1);
    static assert( MatchTuple!(V.elements).With!(1) );

    alias StaticSet!(StaticSet) S;
    static assert(!S.empty);
    static assert( S.length == 1);
    static assert( S.elements.length == 1);
    static assert( MatchTuple!(S.elements).With!(StaticSet) );
}

unittest    // normalization (duplicate items)
{
    alias StaticSet!(1, 2, 3, 2, 1) S_12321;
    alias StaticSet!(1, 2, 3      ) S_123__;
    alias StaticSet!(   2, 3,    1) S__23_1;

    static assert(!S_12321.empty);
    static assert( S_12321.length == 3);
    static assert( S_12321.elements.length == 3);

    static assert(__traits(isSame, S_12321, S_123__));
    static assert(__traits(isSame, S_123__, S__23_1));
}

unittest    // normalization (ordering)
{
    alias StaticSet!(-1.0,  real,     "dee", StaticSet) A;
    alias StaticSet!(real, "dee", StaticSet,      -1.0) B;

    static assert(!A.empty);
    static assert( A.length == 4);
    static assert( A.elements.length == 4);

    static assert(__traits(isSame, A, B));
}


unittest    // comparison for equality
{
    alias StaticSet!(1, 2, 3, 4   ) A;
    alias StaticSet!(   2, 3, 4   ) B;
    alias StaticSet!(1, 2, 3, 4, 5) C;
    alias StaticSet!("12345", real) D;
    alias StaticSet!(             ) E;

    static assert( A.equals!(A));
    static assert(!A.equals!(B));
    static assert(!A.equals!(C));
    static assert(!A.equals!(D));
    static assert(!A.equals!(E));

    // with immediate tuples
    static assert( A.equals!(   1, 2, 3, 4   ));
    static assert( A.equals!(1, 1, 2, 3, 4, 4));
    static assert(!A.equals!(0, 1, 2, 3, 4, 5));
    static assert(!A.equals!(      2, 3, 4   ));
    static assert(!A.equals!("012345", string));
    static assert(!A.equals!(                ));

    // empty
    static assert( E.equals!(E));
    static assert( E.equals!( ));
    static assert(!E.equals!(A));
    static assert(!E.equals!(1));
}

unittest    // mixed elements
{
    alias StaticSet!("12345", real) A;
    static assert( A.equals!("12345",    real));
    static assert( A.equals!(   real, "12345"));
    static assert(!A.equals!("54321",    real));
    static assert(!A.equals!("12345",     int));
}

unittest    // subset
{
    alias StaticSet!(1, 2, int, real, StaticSet) A;

    static assert(A.contains!(A));
    static assert(A.contains!(StaticSet!(         )));
    static assert(A.contains!(StaticSet!(  1,    2)));
    static assert(A.contains!(StaticSet!(int, real)));
    static assert(A.contains!(StaticSet!(StaticSet)));
    static assert(A.contains!(StaticSet!(1, 2, int)));

    static assert(A.contains!(A.elements));
    static assert(A.contains!(   1,    2));
    static assert(A.contains!( int, real));
    static assert(A.contains!( StaticSet));
    static assert(A.contains!( 1, 2, int));

    static assert(!A.contains!(string));
    static assert(!A.contains!(1, 100));
    static assert(!A.contains!(1, 2, int, real, StaticSet, string));

    // empty
    alias StaticSet!() E;
    static assert( E.contains!(E));
    static assert( E.contains!( ));
    static assert(!E.contains!(A));
    static assert(!E.contains!(0));
}


unittest    // add
{
    alias StaticSet!() A;
    alias A.add!(int       ) B;
    alias B.add!(real,  255) C;
    alias C.add!(int       ) D;
    alias D.add!(int, "abc") E;
    static assert(B.equals!(int                  ));
    static assert(C.equals!(int, real, 255       ));
    static assert(D.equals!(int, real, 255       ));
    static assert(E.equals!(int, real, 255, "abc"));

 /+
    [XXX broken!]

    alias StaticSet!() zero;
    alias zero.add!(zero) one;
    alias  one.add!( one) two;
    alias  two.add!( two) three;
    static assert(three.equals!(zero, one, two));
 +/
}

unittest    // remove
{
    alias StaticSet!(int, real, 255, "abc") A;
    alias A.remove!(int       ) B;
    alias B.remove!(real,  255) C;
    alias C.remove!(int       ) D;
    alias D.remove!(int, "abc") E;
    static assert(B.equals!(real, 255, "abc"));
    static assert(C.equals!(           "abc"));
    static assert(D.equals!(           "abc"));
    static assert(E.equals!(                ));
}


unittest    // intersection
{
    alias StaticSet!(2, 3, 5, 7, 11) A;
    alias StaticSet!(1, 3, 5, 7,  9) B;
    static assert(A.intersection!(A).equals!(2, 3, 5, 7, 11));
    static assert(A.intersection!(B).equals!(3, 5, 7));
    static assert(B.intersection!(A).equals!(3, 5, 7));
    static assert(B.intersection!(B).equals!(1, 3, 5, 7,  9));

    static assert(A.intersection!( ).equals!( ));
    static assert(B.intersection!( ).equals!( ));

    static assert(A.intersection!(2, 4, 6).equals!(2));
    static assert(B.intersection!(2, 4, 6).equals!( ));
}

unittest    // union
{
    alias StaticSet!(2, 3, 5, 7, 11) A;
    alias StaticSet!(1, 3, 5, 7,  9) B;
    static assert(A.union_!(A).equals!(2, 3, 5, 7, 11));
    static assert(A.union_!(B).equals!(1, 2, 3, 5,  7, 9, 11));
    static assert(B.union_!(A).equals!(1, 2, 3, 5,  7, 9, 11));
    static assert(B.union_!(B).equals!(1, 3, 5, 7,  9));

    static assert(A.union_!( ).equals!(A.elements));
    static assert(B.union_!( ).equals!(B.elements));

    static assert(A.union_!(2, 4, 6).equals!(   2, 3, 4, 5, 6, 7, 11));
    static assert(B.union_!(2, 4, 6).equals!(1, 2, 3, 4, 5, 6, 7,  9));
}

unittest    // difference
{
    alias StaticSet!(2, 3, 5, 7, 11) A;
    alias StaticSet!(1, 3, 5, 7,  9) B;
    static assert(A.difference!(A).equals!( ));
    static assert(A.difference!(B).equals!(2, 11));
    static assert(B.difference!(A).equals!(1,  9));
    static assert(B.difference!(B).equals!( ));

    static assert(A.difference!( ).equals!(A.elements));
    static assert(B.difference!( ).equals!(B.elements));

    static assert(A.difference!(2, 4, 6).equals!(   3, 5, 7, 11));
    static assert(B.difference!(2, 4, 6).equals!(1, 3, 5, 7,  9));
}

unittest    // symmetric difference
{
    alias StaticSet!(2, 3, 5, 7, 11) A;
    alias StaticSet!(1, 3, 5, 7,  9) B;
    static assert(A.symmetricDifference!(A).equals!( ));
    static assert(A.symmetricDifference!(B).equals!(1, 2, 9, 11));
    static assert(B.symmetricDifference!(A).equals!(1, 2, 9, 11));
    static assert(B.symmetricDifference!(B).equals!( ));

    static assert(A.symmetricDifference!( ).equals!(A.elements));
    static assert(B.symmetricDifference!( ).equals!(B.elements));

    static assert(A.symmetricDifference!(2, 4, 6)
                                .equals!(3, 4, 5, 6, 7, 11));
    static assert(B.symmetricDifference!(2, 4, 6)
                                .equals!(1, 2, 3, 4, 5, 6, 7, 9));
}



// Specified items are always normalized via this hook, so that all the
// following instantiations:
//
//      StaticSet!(2,1,3)  StaticSet!(3,1,2)  StaticSet!(1,1,3,2)
//
// yield the single instance StaticSet!(1,2,3).

template StaticSet(items...)
    if (!isSetElementsNormalized!(items))
{
    alias StaticSet!(NormalizeSetElements!(items)) StaticSet;
}


private template isSetElementsNormalized(items...)
{
    enum isSetElementsNormalized =
        MatchTuple!(items).With!(NormalizeSetElements!(items));
}


// The ordering of StaticSet elements should _always_ be heterogeneousLess
// since set operations assume that all sets have their elements ordered in
// the unified rule.

private alias heterogeneousLess staticSetOrdering;


private template NormalizeSetElements(items...)
{
    alias StaticUniq!(StaticSort!(staticSetOrdering, items))
            NormalizeSetElements;
}


unittest    // empty
{
    alias NormalizeSetElements!() e;
    assert(e.length == 0);
}

unittest    // normalized to single item
{
    alias NormalizeSetElements!(1) I;
    static assert(I.length == 1);
    static assert(I[0] == 1);

    alias NormalizeSetElements!(1, 1, 1, 1, 1) II;
    static assert(II.length == 1);
    static assert(II[0] == 1);
}

unittest    // types
{
    alias NormalizeSetElements!(char, int, real, int, int) N;
    static assert(N.length == 3);
    static assert(!is( N[0] == N[1] ));
    static assert(!is( N[1] == N[2] ));
    static assert(!is( N[2] == N[1] ));
}



/**
 * Returns $(D true) iff $(D set) is an instance of the $(D StaticSet).
 *
 * Example:
 *  The template in the following code utilizes $(D isStaticSet) for seeing
 *  if the given argument is an instance of the $(D StaticSet) or not.
--------------------
template toStaticSet(alias set)
    if (isStaticSet!(set))
{
    // It's already a StaticSet.
    alias set toStaticSet;
}

template toStaticSet(items...)
{
    // Create a StaticSet consisting of the specified items.
    alias StaticSet!(items) toStaticSet;
}
--------------------
 */
template isStaticSet(alias set)
{
    enum isStaticSet = is(set.ContainerTag == StaticSetTag);
}


/// ditto
template isStaticSet(set)
{
    enum isStaticSet = false;
}


unittest    // positive cases
{
    alias StaticSet!(          ) A;
    alias StaticSet!(1         ) B;
    alias StaticSet!(2, int    ) C;
    alias StaticSet!(3, real, A) D;
    static assert(isStaticSet!(A));
    static assert(isStaticSet!(B));
    static assert(isStaticSet!(C));
    static assert(isStaticSet!(D));
}

unittest    // negative cases
{
    struct Set {}
    static assert(!isStaticSet!(int));
    static assert(!isStaticSet!(Set));
    static assert(!isStaticSet!(123));
    static assert(!isStaticSet!(StaticSet)); // not an instance
    static assert(!isStaticSet!(isStaticSet));
}



//----------------------------------------------------------------------------//
// Utilities
//----------------------------------------------------------------------------//
// template interpretNow( T, T value);
// template interpretNow(alias value);
//
// template MatchTuple(items...) . With(rhs...);
//----------------------------------------------------------------------------//


/**
 * Triggers constant folding of $(D value) as an expression of type $(D T).
 *
 * Instantiation fails if $(D value) cannot be evaluated at compile time.
 * So, this template can be used for checking if a template alias parameter
 * is a compile-time constant.  See also the example below.
 *
 * Params:
 *      T = Optional argument to explicitly specify the type of the value,
 *          or $(D typeof(value)) is used if not specified.
 *  value = Expression to evaluate.
 *
 * Returns:
 *  The value.
 *
 * Example:
 *  The following example uses $(D interpretNow) for generating an elaborate
 *  error message when the arugment $(D value) is not a compile-time constant.
--------------------
template mixinStaticStore(alias value)
{
    static assert(__traits(compiles, interpretNow!(value)),
                   "The argument to mixinStaticStore must be able to be "
                  ~"interpreted at compile time!");
    static store = value;
}

static int variable;

mixin mixinStaticStore!(1024);      // succeeds
mixin mixinStaticStore!(variable);  // fails
--------------------
 */
template interpretNow(T, T value)
{
    // Any expression enclosed in a static-if context must be evaluated
    // at compile time (enum allows non-constant expression occasionally).

    static if (interpretNow_(value))
        enum T interpretNow = value;
}

private bool interpretNow_(T)(T value) { return true; }


unittest    // constant and non-constant symbols
{
    enum int constant = 1;
    static assert(interpretNow!(int, constant    ) == 1);
    static assert(interpretNow!(int, constant + 4) == 5);

    int variable;
    static assert(!__traits(compiles, interpretNow!(int, variable    )));
    static assert(!__traits(compiles, interpretNow!(int, variable + 4)));
}

unittest    // convertible/non-convertible types
{
    static assert(interpretNow!(   real,       42) == 42.0L);
    static assert(interpretNow!(dstring, "string") == "string"d);

    static assert(!__traits(compiles, interpretNow!(string, 42)));
    static assert(!__traits(compiles, interpretNow!( void*, 42)));
    static assert(!__traits(compiles, interpretNow!( int[], 42)));
}


/// ditto
template interpretNow(alias value)
{
    alias interpretNow!(typeof(value), value) interpretNow;
}


unittest    // constant and non-constant symbols
{
    enum constant = 1;
    static assert(interpretNow!(constant    ) == 1);
    static assert(interpretNow!(constant + 4) == 5);

    int variable;
    static assert(!__traits(compiles, interpretNow!(variable    )));
    static assert(!__traits(compiles, interpretNow!(variable + 4)));
}



/**
 * Compares two tuples $(D items) and $(D rhs) for equality.
 *
 * Returns:
 *  $(D true) if two tuples are identical, or $(D false) otherwise.
 *
 * Example:
 *  Checking the content of a tuple $(D sequence).
--------------------
alias TypeTuple!(1, 2, 3, 4) sequence;

static assert( MatchTuple!(sequence).With!(1, 2, 3, 4) );
--------------------
 */
template MatchTuple(items...)
{
    /**
     * An instance $(D MatchTuple!(items)) can be reused for multiple
     * comparisons against the same $(D items).
     *
     * Example:
     *  Comparing $(D sequence) and two tuples.
--------------------
alias TypeTuple!(1, 2, 3, 4) sequence;
alias MatchTuple!(sequence) match;

static assert( match.With!(1, 2, 3, 4));
static assert(!match.With!(4, 3, 2, 1));
--------------------
     */
    template With(rhs...)
    {
        // NOTE: Template instances have the same symbol if and only if they
        //       are instantiated with the same arguments.  The following
        //       predicate exploits this fact for comparing items and rhs.

        enum With = __traits(isSame, MatchTuple!(items), MatchTuple!(rhs));
    }
}

unittest    // empty
{
    static assert( MatchTuple!().With!());
    static assert(!MatchTuple!().With!(1));
    static assert(!MatchTuple!().With!(1, 2, 3));
    static assert(!MatchTuple!().With!(int, char));
    static assert(!MatchTuple!().With!(MatchTuple, MatchTuple));
}

unittest    // one element
{
    static assert( MatchTuple!(1).With!(1));
    static assert(!MatchTuple!(1).With!(1, 1, 1));
    static assert(!MatchTuple!(1).With!(2));
    static assert(!MatchTuple!(1).With!(int));
    static assert(!MatchTuple!(1).With!(MatchTuple));
    static assert(!MatchTuple!(1).With!(MatchTuple, int, 3));
}

unittest    // mixed elements
{
    static assert( MatchTuple!(42, int, MatchTuple)
                        .With!(42, int, MatchTuple) );
}

