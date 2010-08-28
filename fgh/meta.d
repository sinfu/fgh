/**
 * $(LINK http://github.com/sinfu/fgh/blob/master/fgh/meta.d)
 *
 * Macros:
 *  D          = $(I $1)
 *  Workaround = $(RED [Workaround]) $0
 *  TODO       = $(RED [TODO]) $0
 */
module fgh.meta;

import std.typetuple : TypeTuple;


unittest
{
    enum a = staticSet!(int,   real);
    enum b = staticSet!(int, string);

    static assert((a | b) == staticSet!(int, real, string));
    static assert((a & b) == staticSet!(int              ));
    static assert((a - b) == staticSet!(     real        ));
    static assert((a ^ b) == staticSet!(     real, string));

    static assert(a in staticSet!(real, bool, int));
    static assert(a.contains!(int));
}

unittest
{
    enum  zero = staticSet!();
    enum   one = zero.add!(zero);
    enum   two =  one.add!( one);
    enum three =  two.add!( two);

    static assert(three == staticSet!(zero, one, two));
}



//----------------------------------------------------------------------------//
// template StaticSort  (less, items...)
// template StaticUniq  (      items...)
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
    alias StaticSort!(genericLess,  int,  real, short) A;
    alias StaticSort!(genericLess, real, short,   int) B;

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
// Sequence
//----------------------------------------------------------------------------//


/**
 * $(D Sequence) simply confines a static tuple inside its template instance.
 *
 * Example:
 *  The following example uses $(D Sequence) for (a) passing multiple tuples
 *  to a template, and for (b) checking the result.
--------------------
template Interleave(alias A, alias B)
    if (A.length == B.length)
{
    static if (A.empty)
        alias TypeTuple!() Interleave;
    else
        alias TypeTuple!(
            A.elements[0],
            B.elements[0],
            Interleave!( Sequence!(A.elements[1 .. $]),
                         Sequence!(B.elements[1 .. $]) )) Interleave;
}

alias Interleave!( Sequence!(1, 3, 5, 7),
                   Sequence!(2, 4, 6, 8) ) result;

static assert(isSame!( Sequence!(result),
                       Sequence!(1, 2, 3, 4, 5, 6, 7, 8) ));
--------------------
 */
template Sequence(items...)
{
private:
    alias SequenceTag   ContainerTag;   // for isSequence

public:

    /**
     * Returns $(D true) if and only if $(D items) is empty.
     */
    enum bool empty = (items.length == 0);


    /**
     * Returns the number of items in the specified $(D items).
     */
    enum size_t length = items.length;


    /**
     * The specified $(D items).
     */
    alias items elements;
}


private enum SequenceTag { init }


/**
 * Returns $(D true) if and only if $(D entity) is an instance of the
 * $(D Sequence) template.
 *
 * Example:
 *  Switching the behavior of a template by seeing if the argument is an
 *  instance of the $(D Sequence) template or not.
--------------------
template toSequence(alias item)
    if (isSequence!(item))
{
    alias item toSequence;  // already a Sequence
}

template toSequence(items...)
{
    alias Sequence!(items) toSequence;
}
--------------------
 */
template isSequence(alias entity)
{
    enum isSequence = is(entity.ContainerTag == SequenceTag);
}


/**
 * ditto
 */
template isSequence(entity...)
{
    enum isSequence = false;
}


unittest    // positive
{
    static assert(isSequence!( Sequence!() ));
    static assert(isSequence!( Sequence!(1) ));
    static assert(isSequence!( Sequence!(1, 2, 3, 4) ));
    static assert(isSequence!( Sequence!(int, real, string) ));
}

unittest    // negative
{
    static struct Local {}
    static assert(!isSequence!( Sequence ));    // not an instance
    static assert(!isSequence!( Local ));
    static assert(!isSequence!( int ));
    static assert(!isSequence!( 4, 3, 2, 1 ));
}



//----------------------------------------------------------------------------//
// template StaticSetIntersection       (A, B, less)
// template StaticSetUnion              (A, B, less)
// template StaticSetDifference         (A, B, less)
// template StaticSetSymmetricDifference(A, B, less)
//----------------------------------------------------------------------------//


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
        alias genericLess adaptiveLess;
    }
}


/**
 * Constructs a sorted static tuple consisting of the set intersection of the
 * two sorted static sequences $(D A) and $(D B).
 *
 * If $(D A) and $(D B) contains $(D m) and $(D n) duplicates of the same
 * element respectively, the resulting union will contain $(D min(m,n))
 * duplicates.
 *
 * Params:
 *     A = $(D Sequence) whose elements $(D A.elements) are sorted in the
 *         increasing order in terms of $(D less).
 *     B = ditto.
 *  less = Comparison template function (optional).
 *
 * Returns:
 *  Static tuple copmosed only of the common elements of $(D A) and $(D B).
 *
 * Example:
--------------------
alias Sequence!(2, 3, 5, 7) primes;
alias Sequence!(1, 3, 5, 7) odds;

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
    alias StaticSetIntersection!(Sequence!(1, 1, 2, 3, 5),
                                 Sequence!(1, 3, 5, 7, 9)) A;
    static assert(MatchTuple!(A).With!(1, 3, 5));

    alias StaticSetIntersection!(Sequence!("abc", "def", "ghi"),
                                 Sequence!("123", "abc", "xyz")) B;
    static assert(MatchTuple!(B).With!("abc"));
}

unittest    // empty intersection
{
    alias StaticSetIntersection!(Sequence!(1, 3, 5, 7, 9),
                                 Sequence!(0, 2, 4, 6, 8)) A;
    static assert(A.length == 0);
}

unittest    // empty \cap sth
{
    alias StaticSetIntersection!(Sequence!(), Sequence!(1, 2, 3)) A;
    static assert(A.length == 0);

    alias StaticSetIntersection!(Sequence!(1, 2, 3), Sequence!()) B;
    static assert(B.length == 0);

    alias StaticSetIntersection!(Sequence!(), Sequence!()) C;
    static assert(C.length == 0);
}

unittest    // duplicate elements
{
    alias StaticSetIntersection!(Sequence!(1, 1, 1, 2, 2, 2),
                                 Sequence!(1, 2, 2, 3, 4, 5)) A;
    static assert(MatchTuple!(A).With!(1, 2, 2));

    alias StaticSetIntersection!(Sequence!(1, 2, 2, 3, 4, 5),
                                 Sequence!(1, 1, 1, 2, 2, 2)) B;
    static assert(MatchTuple!(B).With!(1, 2, 2));
}



/**
 * Constructs a sorted static tuple consisting of the set union of the two
 * sorted sequences $(D A) and $(D B).
 *
 * If $(D A) and $(D B) contains $(D m) and $(D n) duplicates of the same
 * element respectively, the resulting union will contain $(D max(m,n))
 * duplicates.
 *
 * Params:
 *     A = $(D Sequence) whose elements $(D A.elements) are sorted in the
 *         increasing order in terms of $(D less).
 *     B = ditto.
 *  less = Comparison template function (optional).
 *
 * Returns:
 *  Static tuple composed of the elements in $(D A) and/or $(D B).
 *
 * Example:
 *  Union of the first four primes and the first four odd numbers.
--------------------
alias Sequence!(2, 3, 5, 7) primes;
alias Sequence!(1, 3, 5, 7) odds;

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
    alias StaticSetUnion!(Sequence!(1, 1, 3, 5, 8),
                          Sequence!(1, 3, 5, 7, 9)) A;
    static assert(MatchTuple!(A).With!(1, 1, 3, 5, 7, 8, 9));

    alias StaticSetUnion!(Sequence!("abc", "def", "ghi"),
                          Sequence!("def", "ghi", "jkl")) B;
    static assert(MatchTuple!(B).With!("abc", "def", "ghi", "jkl"));
}

unittest    // empty \cup sth
{
    alias Sequence!() E;
    alias Sequence!(1, 2, 3, 4) A;

    alias StaticSetUnion!(E, A) K;
    static assert(MatchTuple!(K).With!(A.elements));

    alias StaticSetUnion!(A, E) L;
    static assert(MatchTuple!(L).With!(A.elements));

    alias StaticSetUnion!(E, E) M;
    static assert(MatchTuple!(M).With!(E.elements));
}

unittest    // duplicate elements
{
    alias StaticSetUnion!(Sequence!(1, 1, 1, 2, 2, 2),
                          Sequence!(1, 2, 2, 3, 4, 5)) A;
    static assert(MatchTuple!(A).With!(1, 1, 1, 2, 2, 2, 3, 4, 5));

    alias StaticSetUnion!(Sequence!(1, 2, 2, 3, 4, 5),
                          Sequence!(1, 1, 1, 2, 2, 2)) B;
    static assert(MatchTuple!(B).With!(1, 1, 1, 2, 2, 2, 3, 4, 5));
}



/**
 * Constructs a sorted static tuple consisting of the set difference of $(D A)
 * with respect to $(D B).
 *
 * Params:
 *     A = $(D Sequence) whose elements $(D A.elements) are sorted in the
 *         increasing order in terms of $(D less).
 *     B = ditto.
 *  less = Comparison template function (optional).
 *
 * Returns:
 *  Static tuple composed of the elements in $(D A) except ones in $(D B).
 *
 * Example:
 *  { 5,15,25 } is only contained in $(D A), hence the difference of $(D A)
 *  with respect to $(D B) is { 5,15,25 }.
--------------------
alias Sequence!( 5, 10, 15, 20, 25) A;
alias Sequence!(10, 20, 30, 40, 50) B;

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
    alias StaticSetDifference!(Sequence!(1, 1, 2, 3, 5),
                               Sequence!(1, 3, 5, 7, 9)) A;
    static assert(MatchTuple!(A).With!(1, 2));

    alias StaticSetDifference!(Sequence!("abc", "def", "ghi"),
                               Sequence!("def", "ghi", "jkl")) B;
    static assert(MatchTuple!(B).With!("abc"));
}

unittest    // empty
{
    alias StaticSetDifference!(Sequence!(), Sequence!(1, 2, 3, 4)) A;
    static assert(A.length == 0);

    alias StaticSetDifference!(Sequence!(1, 2, 3, 4), Sequence!()) B;
    static assert(MatchTuple!(B).With!(1, 2, 3, 4));

    alias StaticSetDifference!(Sequence!(), Sequence!()) C;
    static assert(C.length == 0);
}

unittest    // duplicate elements
{
    alias StaticSetDifference!(Sequence!(1, 1, 1, 2, 2, 2),
                               Sequence!(      1,       2)) A;
    static assert(MatchTuple!(A).With!(1, 1, 2, 2));

    alias StaticSetDifference!(Sequence!(1, 1, 1, 2, 2, 2),
                               Sequence!(1, 1, 1, 1, 2, 2)) B;
    static assert(MatchTuple!(B).With!(2));

    alias StaticSetDifference!(Sequence!(1, 2, 3, 4, 5, 6),
                               Sequence!(1, 1, 1, 2, 2, 2)) C;
    static assert(MatchTuple!(C).With!(3, 4, 5, 6));
}



/**
 * Constructs a sorted static tuple consisting of the set symmetric difference
 * (or the XOR) of two sorted sequences $(D A) and $(D B).
 *
 * Params:
 *     A = $(D Sequence) whose elements $(D A.elements) are sorted in the
 *         increasing order in terms of $(D less).
 *     B = ditto.
 *  less = Comparison template function (optional).
 *
 * Returns:
 *  Static tuple composed of the elements in $(D A) and $(D B) except ones
 *  in the both sequences.
 *
 * Example:
 *  The common element $(D int) does not appear in the result.
--------------------
alias Sequence!(bool, int, void*) Scalars;
alias Sequence!(byte, int, short) Integers;
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
            Sequence!(1, 1, 2, 3, 5),
            Sequence!(1, 3, 5, 7, 9)) A;
    static assert(MatchTuple!(A).With!(1, 2, 7, 9));

    alias StaticSetSymmetricDifference!(
            Sequence!(1, 3, 5, 7, 9),
            Sequence!(1, 1, 2, 3, 5)) revA;
    static assert(MatchTuple!(revA).With!(1, 2, 7, 9));

    alias StaticSetSymmetricDifference!(
            Sequence!("abc", "def", "ghi"),
            Sequence!("def", "ghi", "jkl")) B;
    static assert(MatchTuple!(B).With!("abc", "jkl"));
}

unittest    // empty
{
    alias StaticSetSymmetricDifference!(
            Sequence!(), Sequence!(1, 2, 3, 4)) A;
    static assert(MatchTuple!(A).With!(1, 2, 3, 4));

    alias StaticSetSymmetricDifference!(
            Sequence!(1, 2, 3, 4), Sequence!()) B;
    static assert(MatchTuple!(B).With!(1, 2, 3, 4));

    alias StaticSetSymmetricDifference!(Sequence!(), Sequence!()) C;
    static assert(C.length == 0);
}

unittest    // duplicate elements
{
    alias StaticSetSymmetricDifference!(
            Sequence!(1, 1, 1, 2, 2, 2),
            Sequence!(1, 2, 3, 4, 5   )) A;
    static assert(MatchTuple!(A).With!(1, 1, 2, 2, 3, 4, 5));

    alias StaticSetSymmetricDifference!(
            Sequence!(1, 2, 3, 4, 5   ),
            Sequence!(1, 1, 1, 2, 2, 2)) revA;
    static assert(MatchTuple!(revA).With!(1, 1, 2, 2, 3, 4, 5));

    alias StaticSetSymmetricDifference!(
            Sequence!(1, 1, 1, 2, 2, 2),
            Sequence!(2, 2, 2, 3, 3   )) B;
    static assert(MatchTuple!(B).With!(1, 1, 1, 3, 3));
}



//----------------------------------------------------------------------------//
// Tiarg Comparators
//----------------------------------------------------------------------------//
// template standardLess(items...);
// template  genericLess(items...);
// template       isSame(items...);
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
 * Returns:
 *  $(D true) if and only if $(D items[0] < ... < items[$ - 1]).  Returns
 *  $(D false) otherwise.
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
    if (items.length >= 2)
{
    static if (items.length > 2)
    {
        enum standardLess = standardLess!(items[0 .. 2]) &&
                            standardLess!(items[1 .. $]);
    }
    else
    {
        // NOTE: Use static this so the expression is evaluated right now.

        static if (items[0] < items[1])
            enum standardLess =  true;
        else
            enum standardLess = false;
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
 * Compares compile-time entities $(D items...) by their mangled names.
 * The tuple $(D items) may consist of any kind of compile-time entities
 * (unlike the restrictive $(D standardLess) template).
 *
 * The point of this template is to allow comparison against types and
 * symbols so that tuples of such kind of entities can be normalized by
 * sorting.  The example below sorts type tuples with $(D genericLess).
 *
 * Params:
 *  items = Two or more compile time entities of any kind.
 *
 * Returns:
 *  $(D true) if and only if $(D items[0] < ... < items[$ - 1]) is
 *  satisfied in terms of their mangled names.  Returns $(D false)
 *  otherwise.
 *
 * Example:
 *  Sorting type tuples.
--------------------
alias StaticSort!(genericLess,  int,  real, short) A;
alias StaticSort!(genericLess, real, short,   int) B;

// The two type tuples are sorted (or normalized).
static assert(is(A == TypeTuple!(real, int, short)));
static assert(is(B == TypeTuple!(real, int, short)));
--------------------
 */
template genericLess(items...)
    if (items.length >= 2)
{
    static if (items.length > 2)
        enum genericLess = genericLess!(items[0 .. 2]) &&
                           genericLess!(items[1 .. $]);
    else
        enum genericLess = (metaEntity!(items[0]).id <
                            metaEntity!(items[1]).id);
}


unittest    // integers
{
    static assert( genericLess!(1, 2));
    static assert(!genericLess!(2, 1));
    static assert( genericLess!(1, 2, 3, 4));
    static assert(!genericLess!(1, 3, 2, 4));
    static assert(!genericLess!(-1,  1));
    static assert( genericLess!( 1, -1));
}

unittest    // types
{
    static assert(char.mangleof == "a");
    static assert(real.mangleof == "e");
    static assert( int.mangleof == "i");
    static assert(bool.mangleof == "b");
    static assert( genericLess!(char, real,  int));
    static assert(!genericLess!(bool, real, char));

    struct A {}
    struct B {}
    struct C {}
    static assert( genericLess!(A, B));
    static assert( genericLess!(B, C));
    static assert( genericLess!(A, B, C));
    static assert(!genericLess!(B, C, A));
}

unittest    // symbols
{
    static assert( genericLess!( genericLess, standardLess));
    static assert(!genericLess!(standardLess, int));
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


// isSame detail

private template isSame_(A, B)
{
    enum isSame_ = is(A == B);
}

private template isSame_(alias a, alias b)
{
    static if (is(typeof(a) A) && is(typeof(b) B))
    {
        static if (__traits(compiles, interpretNow!(bool, a == b)))
            enum isSame_ = is(A == B) && (a == b);
        else
            enum isSame_ = __traits(isSame, a, b);
    }
    else
    {
        enum isSame_ = __traits(isSame, a, b);
    }
}

private template isSame_(items...)
    if (items.length == 2)
{
    enum isSame_ = (metaEntity!(items[0]) == metaEntity!(items[1]));
}



//----------------------------------------------------------------------------//
// Static Set
//----------------------------------------------------------------------------//
// enum StaticSet   staticSet!(items...);        // constructor
//
// struct StaticSet(items...)
// {
//     enum bool   empty;
//     enum size_t length;
//     alias       elements;
//
//     auto        add              (items...);
//     auto        remove           (items...);
//
//     bool        opEquals         (rhs);
//     bool        opBinary!"in"    (rhs);      // is subset of ...
//     bool        contains         (items...); // contains ...
//
//     auto        opBinary!"&"     (rhs);      // intersection
//     auto        opBinary!"|"     (rhs);      // union
//     auto        opBinary!"-"     (rhs);      // difference
//     auto        opBinary!"^"     (rhs);      // symmetric difference
// }
//----------------------------------------------------------------------------//


/**
 * $(D StaticSet) is a collection of compile-time entities (types, symbols
 * and/or constants) in which order has no significance and duplicate
 * elements are ignored.
 *
 * Example:
--------------------
enum signed = staticSet!(byte, short, int, long);
enum   tiny = staticSet!(bool, byte, ubyte);
--------------------
 */
immutable @safe struct StaticSet(items...)
    if (isSetElementsNormalized!(items))
{
private:
    alias StaticSetTag    ContainerTag;   // for isStaticSet
    alias StaticSet!items This;           // non-qualified type
    enum                  self = This();  // instance


public pure nothrow:

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
     * The unique _elements in the set.
     *
     * See_Also:
     *  The global template $(D .elements(c)).
     */
    alias items elements;



    //----------------------------------------------------------------//
    // Container Operations
    //----------------------------------------------------------------//


    /**
     * Returns a $(D StaticSet) object composed of the elements in this set
     * and $(D ritems).
     *
     * Params:
     *  items = Compile-time entities to _add to the set.  Note that sets
     *          ($(D StaticSet) instances) in $(D items) are never expanded
     *          and the symbols of the sets itselves are added.  In such a
     *          case, the resulting set will be a set of sets.
     *
     * Returns:
     *  The union of this set and $(D {items...}).
     *
     * Examples:
     *  Set of sets.
--------------------
enum  zero = staticSet!( );
enum   one = zero.add!(zero);
enum   two =  one.add!( one);
enum three =  two.add!( two);

static assert(three.length == 3);
static assert(three == staticSet!(zero, one, two));
--------------------
     */
    OpBinary!(StaticSetUnion, StaticSet!(ritems))
        add(ritems...)()
    {
        return this | staticSet!(ritems);
    }


  /+@@@BUG3598@@@
    unittest
    {
        static assert(self.add!() == self);
    }
  +/



    /**
     * Returns a $(D StaticSet) object composed of the elements in this set
     * except $(D ritems).
     *
     * Params:
     *  items = Compile-time entities to _remove from this set.  $(D items)
     *          may contain entities not contained in this set; such _items
     *          are simply ignored.
     *
     * Returns:
     *  The difference of this set with regard to $(D {items...}).
     *
     * Example:
     *  Removing $(D byte) and $(D ubyte) from the set of the built-in signed
     *  integral types.  $(D ubyte) is not in the set and just ignored.
--------------------
enum signed = staticSet!(byte, short, int, long);
enum longer = signed.remove!(byte, ubyte);

static assert(longer == staticSet!(short, int, long));
--------------------
     */
    OpBinary!(StaticSetDifference, StaticSet!(ritems))
        remove(ritems...)()
    {
        return this - staticSet!(ritems);
    }


  /+@@@BUG3598@@@
    unittest
    {
        static assert(self.remove!(elements) == staticSet!());
        static struct Local {}
        static assert(self.remove!(Local) == self);
    }
  +/



    //----------------------------------------------------------------//
    // Comparison
    //----------------------------------------------------------------//


    /**
     * The equality expression $(D a == b) evaluates to $(D true) if $(D a)
     * and $(D b) are equivalent.
     *
     * Example:
     *  The order of elements is not significant for set comparison.
--------------------
enum a = staticSet!(  real, 1, 2, 3, string);
enum b = staticSet!(string, 3, 1, 2,   real);

static assert(a == b);
--------------------
     */
    bool opEquals(ritems...)(StaticSet!(ritems) )
    {
        return is(StaticSet!(items) == StaticSet!(ritems));
    }


  /+@@@BUG3598@@@
    unittest
    {
        static struct Local {}
        static assert(self == self);
        static assert(self.add!(Local) != self);
    }
  +/



    /**
     * The $(D in) expression $(D a in b) evaluates to $(D true) if $(D a)
     * is a subset of $(D b).
     *
     * Example:
--------------------
enum natural = staticSet!(1, 2, 3, 4, 5, 6, 7, 8, 9);
enum    even = staticSet!(   2,    4,    6,    8   );

static assert(   even  in natural);
static assert(natural !in    even);
--------------------
     */
    bool opBinary(string op : "in", R : StaticSet!ritems, ritems...)(R rhs)
    {
        return this == (this & rhs);
    }


  /+@@@BUG3598@@@
    unittest
    {
        static struct Local {}
        enum ext = self.add!(Local);
        static assert(self in self);
        static assert(self in  ext);
        static assert(ext !in self);
    }
  +/



    /**
     * Returns $(D true) if all $(D ritems) are contained in this set.
     */
    template contains(ritems...)
    {
        enum contains = (staticSet!(ritems) in self);
    }


  /+@@@BUG3598@@@
    unittest
    {
        static assert(self.contains!(This.elements));
        static assert(self.contains!(             ));
    }
  +/



    //----------------------------------------------------------------//
    // Set Operations
    //----------------------------------------------------------------//


    /**
     * The $(D and expression) $(D a & b) evaluates to the set intersection
     * of $(D a) and $(D b).
     *
     * Returns:
     *  $(D StaticSet) object composed of the elements that are commonly
     *  contained in both sides.
     *
     * See_Also:
     *  $(D StaticSetIntersection)
     */
    OpBinary!(StaticSetIntersection, R)
        opBinary(string op : "&", R : StaticSet!ritems, ritems...)(R )
    {
        return typeof(return)();
    }


  /+@@@BUG3598@@@
    unittest
    {
        enum zero = staticSet!();
        static assert((self & self) == self);
        static assert((self & zero) == zero);
        static assert((zero & self) == zero);
    }
  +/



    /**
     * The $(D or expression) $(D a | b) evaluates to the set union of
     * $(D a) and $(D b).
     *
     * Returns:
     *  $(D StaticSet) object composed only of the elements that are
     *  commonly contained in both sides.
     *
     * See_Also:
     *  $(D StaticSetUnion), $(D StaticSet.add)
     */
    OpBinary!(StaticSetUnion, R)
        opBinary(string op : "|", R : StaticSet!ritems, ritems...)(R )
    {
        return typeof(return)();
    }


  /+@@@BUG3598@@@
    unittest
    {
        enum zero = staticSet!();
        static assert((self | self) == self);
        static assert((self | zero) == self);
        static assert((zero | self) == self);
    }
  +/



    /**
     * The $(D minus expression) $(D a - b) evaluates to the set difference
     * of $(D a) with regard to $(D b).
     *
     * Returns:
     *  $(D StaticSet) object composed of the elements in $(D a) except ones
     *  in $(D b).
     *
     * See_Also:
     *  $(D StaticSetDifference), $(D StaticSet.remove)
     */
    OpBinary!(StaticSetDifference, R)
        opBinary(string op : "-", R : StaticSet!ritems, ritems...)(R )
    {
        return typeof(return)();
    }


  /+@@@BUG3598@@@
    unittest
    {
        enum zero = staticSet!();
        static assert(self - self == zero);
        static assert(self - zero == self);
        static assert(zero - self == zero);
    }
  +/



    /**
     * The $(D xor expression) $(D a ^ b) evaluates to the set symmetric
     * difference of $(D a) and $(D b).
     *
     * Returns:
     *  $(D StaticSet) object composed of the elements in $(D a) and $(D b)
     *  except ones commonly contained in both.
     *
     * See_Also:
     *  $(D StaticSetSymmetricDifference)
     */
    OpBinary!(StaticSetSymmetricDifference, R)
        opBinary(string op : "^", R : StaticSet!ritems, ritems...)(R )
    {
        return typeof(return)();
    }


  /+@@@BUG3598@@@
    unittest
    {
        enum zero = staticSet!();
        static assert((self ^ self) == zero);
        static assert((self ^ zero) == self);
        static assert((zero ^ self) == self);
    }
  +/



    //----------------------------------------------------------------//
    // Details
    //----------------------------------------------------------------//
private:

    template OpBinary(alias setOperation, R)
    {
        alias StaticSet!(
                setOperation!( Sequence!(  elements),
                               Sequence!(R.elements),
                               staticSetOrdering )) OpBinary;
    }
}


/**
 * ditto
 */
template staticSet(items...)
{
    enum staticSet = StaticSet!items();
}


unittest    // zero or single element
{
    enum e = staticSet!();
    static assert(e.empty);
    static assert(e.length == 0);
    static assert( MatchTuple!(elements!e).With!() );

    enum t = staticSet!(int);
    static assert(!t.empty);
    static assert( t.length == 1);
    static assert( MatchTuple!(elements!t).With!(int) );

    enum v = staticSet!(1);
    static assert(!v.empty);
    static assert( v.length == 1);
    static assert( MatchTuple!(elements!v).With!(1) );

    enum s = staticSet!(StaticSet);
    static assert(!s.empty);
    static assert( s.length == 1);
    static assert( MatchTuple!(elements!s).With!(StaticSet) );
}

unittest    // normalization (duplicate items)
{
    enum s_12321 = staticSet!(1, 2, 3, 2, 1);
    enum s_123__ = staticSet!(1, 2, 3      );
    enum s__23_1 = staticSet!(   2, 3,    1);

    static assert(!s_12321.empty);
    static assert( s_12321.length == 3);
    static assert( elements!s_12321.length == 3);

    static assert(is( typeof(s_12321) == typeof(s_123__) ));
    static assert(is( typeof(s_12321) == typeof(s__23_1) ));
}

unittest    // normalization (ordering)
{
    enum a = staticSet!(-1.0,  real,     "dee", StaticSet);
    enum b = staticSet!(real, "dee", StaticSet,      -1.0);

    static assert(!a.empty);
    static assert( a.length == 4);
    static assert( elements!a.length == 4);

    static assert(is( typeof(a) == typeof(b) ));
}


unittest    // comparison for equality
{
    enum a = staticSet!(1, 2, 3, 4   );
    enum b = staticSet!(   2, 3, 4   );
    enum c = staticSet!(1, 2, 3, 4, 5);
    enum d = staticSet!("12345", real);
    enum e = staticSet!(             );

    static assert(a == a);
    static assert(a != b);
    static assert(a != c);
    static assert(a != d);
    static assert(a != e);

    // empty
    static assert(e == e);
    static assert(e != a);
}

unittest    // mixed elements
{
    enum a = staticSet!("12345", real);
    static assert(a == staticSet!("12345", real));
    static assert(a != staticSet!("54321", real));
    static assert(a != staticSet!("12345",  int));
}

unittest    // subset
{
    enum a = staticSet!(1, 2, int, real, StaticSet);

    static assert(                    a in a);
    static assert(staticSet!(         ) in a);
    static assert(staticSet!(  1,    2) in a);
    static assert(staticSet!(int, real) in a);
    static assert(staticSet!(StaticSet) in a);
    static assert(staticSet!(1, 2, int) in a);

    static assert(a.contains!(elements!a));
    static assert(a.contains!(   1,    2));
    static assert(a.contains!( int, real));
    static assert(a.contains!( StaticSet));
    static assert(a.contains!( 1, 2, int));

    static assert(!a.contains!(string));
    static assert(!a.contains!(1, 100));
    static assert(!a.contains!(1, 2, int, real, StaticSet, string));

    // empty
    enum e = staticSet!();
    static assert( e.contains!( ));
    static assert(!e.contains!(0));
    static assert(  e in e );
    static assert(!(a in e));
}


unittest    // add
{
    enum a = staticSet!();
    enum b = a.add!(int       );
    enum c = b.add!(real,  255);
    enum d = c.add!(int       );
    enum e = d.add!(int, "abc");
    static assert(b == staticSet!(int                  ));
    static assert(c == staticSet!(int, real, 255       ));
    static assert(d == staticSet!(int, real, 255       ));
    static assert(e == staticSet!(int, real, 255, "abc"));

    enum  zero = staticSet!();
    enum   one = zero.add!(zero);
    enum   two =  one.add!( one);
    enum three =  two.add!( two);
    static assert(three == staticSet!(zero, one, two));
}

unittest    // remove
{
    enum a = staticSet!(int, real, 255, "abc");
    enum b = a.remove!(int       );
    enum c = b.remove!(real,  255);
    enum d = c.remove!(int       );
    enum e = d.remove!(int, "abc");
    static assert(b == staticSet!(real, 255, "abc"));
    static assert(c == staticSet!(           "abc"));
    static assert(d == staticSet!(           "abc"));
    static assert(e == staticSet!(                ));
}


unittest    // intersection
{
    enum a = staticSet!(2, 3, 5, 7, 11);
    enum b = staticSet!(1, 3, 5, 7,  9);
    static assert((a & a) == staticSet!(2, 3, 5, 7, 11));
    static assert((a & b) == staticSet!(3, 5, 7));
    static assert((b & a) == staticSet!(3, 5, 7));
    static assert((b & b) == staticSet!(1, 3, 5, 7,  9));

    static assert((a & staticSet!( )) == staticSet!( ));
    static assert((b & staticSet!( )) == staticSet!( ));

    static assert((a & staticSet!(2, 4, 6)) == staticSet!(2));
    static assert((b & staticSet!(2, 4, 6)) == staticSet!( ));
}

unittest    // union
{

    alias staticSet set;

    enum a = set!(2, 3, 5, 7, 11);
    enum b = set!(1, 3, 5, 7,  9);
    static assert((a | a) == set!(2, 3, 5, 7, 11));
    static assert((a | b) == set!(1, 2, 3, 5,  7, 9, 11));
    static assert((b | a) == set!(1, 2, 3, 5,  7, 9, 11));
    static assert((b | b) == set!(1, 3, 5, 7,  9));

    static assert((a | set!( )) == set!(elements!a));
    static assert((b | set!( )) == set!(elements!b));

    static assert((a | set!(2, 4, 6)) == set!(   2, 3, 4, 5, 6, 7, 11));
    static assert((b | set!(2, 4, 6)) == set!(1, 2, 3, 4, 5, 6, 7,  9));
}

unittest    // difference
{
    enum a = staticSet!(2, 3, 5, 7, 11);
    enum b = staticSet!(1, 3, 5, 7,  9);
    static assert((a - a) == staticSet!( ));
    static assert((a - b) == staticSet!(2, 11));
    static assert((b - a) == staticSet!(1,  9));
    static assert((b - b) == staticSet!( ));

    static assert((a - staticSet!( )) == staticSet!(elements!a));
    static assert((b - staticSet!( )) == staticSet!(elements!b));

    static assert((a - staticSet!(2, 4, 6)) == staticSet!(   3, 5, 7, 11));
    static assert((b - staticSet!(2, 4, 6)) == staticSet!(1, 3, 5, 7,  9));
}

unittest    // symmetric difference
{
    enum a = staticSet!(2, 3, 5, 7, 11);
    enum b = staticSet!(1, 3, 5, 7,  9);

    static assert((a ^ a) == staticSet!( ));
    static assert((a ^ b) == staticSet!(1, 2, 9, 11));
    static assert((b ^ a) == staticSet!(1, 2, 9, 11));
    static assert((b ^ b) == staticSet!( ));

    static assert((a ^ staticSet!( )) == staticSet!(elements!a));
    static assert((b ^ staticSet!( )) == staticSet!(elements!b));

    static assert((a ^ staticSet!(2, 4, 6)) == 
                       staticSet!(3, 4, 5, 6, 7, 11));
    static assert((b ^ staticSet!(2, 4, 6)) ==
                       staticSet!(1, 2, 3, 4, 5, 6, 7, 9));
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


// The ordering of StaticSet elements should _always_ be genericLess since
// set operations assume that all sets have their elements ordered in the
// unified rule.

private alias genericLess staticSetOrdering;


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



private enum StaticSetTag { init }


/**
 * Returns $(D true) iff $(D set) is a $(D StaticSet) object.
 *
 * Example:
 *  The template in the following code utilizes $(D isStaticSet) for seeing
 *  if the given argument is an instance of the $(D StaticSet) or not.
--------------------
template toStaticSet(alias set)
    if (isStaticSet!(set))
{
    // It's already a StaticSet.
    enum toStaticSet = set;
}

template toStaticSet(items...)
{
    // Create a StaticSet consisting of the specified items.
    enum toStaticSet = staticSet!(items);
}
--------------------
 */
template isStaticSet(alias set)
{
    enum isStaticSet = is(set.ContainerTag == StaticSetTag);
}


/**
 * ditto
 */
template isStaticSet(set...)
{
    enum isStaticSet = false;
}


unittest    // positive cases
{
    enum a = staticSet!(          );
    enum b = staticSet!(1         );
    enum c = staticSet!(2, int    );
    enum d = staticSet!(3, real, a);
    static assert(isStaticSet!(a));
    static assert(isStaticSet!(b));
    static assert(isStaticSet!(c));
    static assert(isStaticSet!(d));
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
// Meta Entity
//----------------------------------------------------------------------------//
// struct MetaEntity(entity)
// {
//     alias    Tag;
//     enum     id;
//     bool     opEquals(rhs);
//     string   toString();
// }
// template     metaEntity(entity);
//----------------------------------------------------------------------------//


private enum EntityCategory
{
    type,
    symbol,
    constant,
    tuple,
}


/**
 * $(D MetaEntity) represents a compile-time entity: type, symbol, constant
 * or tuple of them.
 *
 * Example:
--------------------
static assert( metaEntity!(int) == metaEntity!(int ) );
static assert( metaEntity!(int) != metaEntity!(real) );
--------------------
 *
 * BUGS:
 *  $(TODO Distinguish non-tuple entities with single-element tuples.)
 */
@safe
immutable struct MetaEntity(entity...)
{
@safe pure nothrow:

    alias MetaEntity Tag;


    enum string id = Tag.mangleof;


    bool opEquals(R)(R )
    {
        return is(Tag == R.Tag);
    }


    string toString()
    {
        return Tag.stringof;
    }
}


/**
 * ditto
 */
template metaEntity(entity...)
{
    enum metaEntity = MetaEntity!entity();
}




//----------------------------------------------------------------------------//
// Utilities
//----------------------------------------------------------------------------//
// template elements        (c);
//
// template interpretNow    ( T, T value);
// template interpretNow    (alias value);
//
// template MatchTuple      (items...) . With(rhs...);
//
// template Repeat          (size_t n, group...);
//----------------------------------------------------------------------------//


/**
 * Uniform interface for obtaining the _elements in a meta collection.
 *
 * $(Workaround
 *  The current compiler implementation rewrites $(D c.(e1, e2 ...)) to
 *  $(D (c.e1, c.e2, ...)) always when $(D c) is an expression.  And
 *  $(D c._elements) cannot be used as a usual static tuple due to the
 *  behavior.  This template would be used as a workaround for the problem.
--------------------
struct S(items...)
{
    alias items elements;
}
S!(1, 2, 3, 4) s;
int[] array = [ s.elements ];   // error...
--------------------
 * )
 *
 * Params:
 *  c = Constant expression or the symbol of a meta collection in which
 *      $(D c._elements) is a static tuple of compile-time entities.
 *
 * Returns:
 *  The static tuple $(D c._elements).
 *
 * Example:
--------------------
enum a = staticSet!(1, 3, 5, 7);
enum b = staticSet!(2, 3, 4, 5);

/+
int[] axorb = [ (a ^ b).elements ]; // this doesn't work
 +/
int[] axorb = [ elements!(a ^ b) ]; // workaround

assert(axorb == [ 1, 2, 4, 7 ]);
--------------------
 */
template elements(alias c)
{
    static if (is(c C) || is(typeof(c) C))
        alias C.elements elements;
    else
        alias c.elements elements;
}


/// ditto
template elements(c)
{
    alias c.elements elements;
}


unittest    // constant symbol
{
    static struct Local(items...)
    {
        alias items elements;
    }
    enum a = Local!(                 )();
    enum b = Local!(  1,    2,      3)();
    enum c = Local!(int, real, string)();
    static assert(MatchTuple!(elements!(a)).With!(                 ));
    static assert(MatchTuple!(elements!(b)).With!(  1,    2,      3));
    static assert(MatchTuple!(elements!(c)).With!(int, real, string));
}

unittest    // constant expression
{
    static struct Local(items...)
    {
        alias items elements;
    }
    static Local!(items) type(items...)() @property
    {
        return Local!(items)();
    }
    static assert(MatchTuple!(elements!( type!(1, 2, 3) )).With!(1, 2, 3));
    static assert(MatchTuple!(elements!( type!(wstring) )).With!(wstring));
}

unittest    // type
{
    static struct Local(items...)
    {
        alias items elements;
    }
    static assert(MatchTuple!(elements!( Local!(1, 2, 3) )).With!(1, 2, 3));
    static assert(MatchTuple!(elements!( Local!(wstring) )).With!(wstring));
}


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
                   "The argument to mixinStaticStore must be "
                  ~"evaluateable at compile time!");
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


/**
 * ditto
 */
template interpretNow(alias value)
{
    alias interpretNow!(typeof(value), value) interpretNow;
}


unittest    // immediate values
{
    static struct S { int n; }
//  static assert(interpretNow!(12345678) == 12345678); // @@@why?
    static assert(interpretNow!("string") == "string");
    static assert(interpretNow!(S(12345)) == S(12345));
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
        // NOTE: Template instances have the same symbol if and only if
        //       they are instantiated with the same arguments.

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



/**
 * Returns a tuple in which a _group of compile-time entities $(D group...)
 * repeats $(D n) times.
 *
 * Params:
 *      n = Zero or more number of repetition.
 *  group = Compile-time entitites to repeat.
 *
 * Returns:
 *  Static tuple consisting of $(D n) $(D group)s.
 *
 * Example:
 *  Using $(D Repeat) for static foreach.
--------------------
// Prints "0u 1u 2u 3u 4u 5u" at compile time.
foreach (i, _; Repeat!(6, void))
{
    pragma(msg, i);
}
--------------------
 */
template Repeat(size_t n, group...)
{
    static if (n == 0 || group.length == 0)
    {
        alias TypeTuple!() Repeat;
    }
    else
    {
        alias TypeTuple!(group, Repeat!(n - 1, group)) Repeat;
    }
}


unittest    // zero time
{
    alias Repeat!(0) A;
    static assert(A.length == 0);

    alias Repeat!(0, int) B;
    static assert(B.length == 0);

    alias Repeat!(0, int, real, string) C;
    static assert(C.length == 0);
}

unittest    // one time
{
    alias Repeat!(1) A;
    static assert(A.length == 0);

    alias Repeat!(1, int) B;
    static assert(MatchTuple!(B).With!(int));

    alias Repeat!(1, int, real, string) C;
    static assert(MatchTuple!(C).With!(int, real, string));
}

unittest    // two or more
{
    alias Repeat!(2) A;
    static assert(A.length == 0);

    alias Repeat!(2, int) B;
    static assert(MatchTuple!(B).With!(int, int));

    alias Repeat!(2, int, real, string) C;
    static assert(MatchTuple!(C).With!(int, real, string,
                                       int, real, string));

    alias Repeat!(4, A) D;
    static assert(MatchTuple!(D).With!(A, A, A, A));

    alias Repeat!(6, A, B, C) E;
    static assert(MatchTuple!(E).With!(A, B, C,  A, B, C,  A, B, C,
                                       A, B, C,  A, B, C,  A, B, C));
}



/**
Retrieves the members of an enumerated type $(D enum E).

Params:
 E = An enumerated type. $(D E) may have duplicated elements.

Returns:
 Static tuple composed of the members of the enumerated type $(D E).
 The members are arranged in the same order as declared in $(D E).

Example:
 The following function $(D rank(v)) uses the $(D EnumMembers) template
 for finding a member $(D e) in an enumerated type $(D E).
--------------------
// Returns i if e is the i-th enumerator of E.
size_t rank(E)(E e)
    if (is(E == enum))
{
    foreach (i, member; EnumMembers!E)
    {
        if (e == member)
            return i;
    }
    assert(0, "Not an enum member");
}

enum Mode
{
    read  = 1,
    write = 2,
    map   = 4,
}
assert(rank(Mode.read ) == 0);
assert(rank(Mode.write) == 1);
assert(rank(Mode.map  ) == 2);
--------------------
 */
template EnumMembers(E)
    if (is(E == enum))
{
    alias EnumSpecificMembers!(E, __traits(allMembers, E)) EnumMembers;
}

private template EnumSpecificMembers(Enum, names...)
{
    static if (names.length > 0)
    {
        alias TypeTuple!(
                namedConstant!(
                    names[0], __traits(getMember, Enum, names[0])),
                EnumSpecificMembers!(Enum, names[1 .. $])
            ) EnumSpecificMembers;
    }
    else
    {
        alias TypeTuple!() EnumSpecificMembers;
    }
}


// The identifier of each enum member will be exposed via this template
// once the BUG4732 is fixed.
//
//   enum E { member }
//   assert(__traits(identifier, EnumMembers!E[0]) == "member");
//
private template namedConstant(string name, alias value)
{
    mixin("alias _namedConstant!(name, value)."~ name ~" namedConstant;");
}

private template _namedConstant(string name, alias _namedConstant_value)
{
    mixin("enum "~ name ~" = _namedConstant_value;");
}


unittest
{
    enum A { a }
    static assert([ EnumMembers!A ] == [ A.a ]);
    enum B { a, b, c, d, e }
    static assert([ EnumMembers!B ] == [ B.a, B.b, B.c, B.d, B.e ]);
}

unittest    // typed enums
{
    enum A : string { a = "alpha", b = "beta" }
    static assert([ EnumMembers!A ] == [ A.a, A.b ]);

    static struct S
    {
        int value;
        int opCmp(S rhs) nothrow { return value - rhs.value; }
    }
    enum B : S { a = S(1), b = S(2), c = S(3) }
    static assert([ EnumMembers!B ] == [ B.a, B.b, B.c ]);
}

unittest    // duplicated values
{
    enum A
    {
        a = 0, b = 0,
        c = 1, d = 1, e
    }
    static assert([ EnumMembers!A ] == [ A.a, A.b, A.c, A.d, A.e ]);
}



//----------------------------------------------------------------------------//
// StaticSwitch
//----------------------------------------------------------------------------//


/**
 *
 * Examples:
 *  Switch over enum, return a type.
--------------------
enum Precision
{
    integral,
    single,
    maximum
}
alias StaticSwitch!( Precision.single ).
    .Case!( Precision.integral, int   )
    .Case!( Precision.single,   float )
    .Case!( Precision.maximum,  real  )
    .Finish T;
static assert(is( T == float ));
--------------------
 *
 *  Switch over type, return a constant.
--------------------
enum a = StaticSwitch!( real )
        .Case!(  int, "integer"        )
        .Case!( real, "floating point" )
   .Otherwise!(       "dunno"          );

static assert(a == "floating point");
--------------------
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

