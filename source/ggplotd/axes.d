module ggplotd.axes;

import std.typecons : Tuple;

version (unittest)
{
    import dunit.toolkit;
}

/++
Struct holding details on axis
+/
struct Axis
{
    /// Creating axis giving a minimum and maximum value
    this(double newmin, double newmax)
    {
        min = newmin;
        max = newmax;
        min_tick = min;
    }

    /// Label of the axis
    string label;

    /// Minimum value of the axis
    double min;
    /// Maximum value of the axis
    double max;
    /// Location of the lowest tick
    double min_tick = -1;
    /// Distance between ticks
    double tick_width = 0.2;

    /// Offset of the axis
    double offset;
}

/// XAxis
struct XAxis {
    /// The general Axis struct
    Axis axis;
    alias axis this;
}

/// YAxis
struct YAxis {
    /// The general Axis struct
    Axis axis;
    alias axis this;
}

/**
    Is the axis properly initialized? Valid range.
*/
bool initialized( in Axis axis )
{
    import std.math : isNaN;
    if ( isNaN(axis.min) || isNaN(axis.max) || axis.max <= axis.min )
        return false;
    return true;
}

unittest
{
    auto ax = Axis();
    assert( !initialized( ax ) );
    ax.min = -1;
    assert( !initialized( ax ) );
    ax.max = -1;
    assert( !initialized( ax ) );
    ax.max = 1;
    assert( initialized( ax ) );
}

/**
    Calculate optimal tick width given an axis and an approximate number of ticks
    */
Axis adjustTickWidth(Axis axis, size_t approx_no_ticks)
{
    import std.math : abs, floor, ceil, pow, log10;
    assert( initialized(axis), "Axis range has not been set" );

    auto axis_width = axis.max - axis.min;
    auto scale = cast(int) floor(log10(axis_width));
    auto acceptables = [0.1, 0.2, 0.5, 1.0, 2.0, 5.0]; // Only accept ticks of these sizes
    auto approx_width = pow(10.0, -scale) * (axis_width) / approx_no_ticks;
    // Find closest acceptable value
    double best = acceptables[0];
    double diff = abs(approx_width - best);
    foreach (accept; acceptables[1 .. $])
    {
        if (abs(approx_width - accept) < diff)
        {
            best = accept;
            diff = abs(approx_width - accept);
        }
    }
    axis.tick_width = best * pow(10.0, scale);
    // Find good min_tick
    axis.min_tick = ceil(axis.min * pow(10.0, -scale)) * pow(10.0, scale);
    //debug writeln( "Here 120 ", axis.min_tick, " ", axis.min, " ", 
    //		axis.max,	" ", axis.tick_width, " ", scale );
    while (axis.min_tick - axis.tick_width > axis.min)
        axis.min_tick -= axis.tick_width;
    return axis;
}

unittest
{
    adjustTickWidth(Axis(0, .4), 5);
    adjustTickWidth(Axis(0, 4), 8);
    assert(adjustTickWidth(Axis(0, 4), 5).tick_width == 1.0);
    assert(adjustTickWidth(Axis(0, 4), 8).tick_width == 0.5);
    assert(adjustTickWidth(Axis(0, 0.4), 5).tick_width == 0.1);
    assert(adjustTickWidth(Axis(0, 40), 8).tick_width == 5);
    assert(adjustTickWidth(Axis(-0.1, 4), 8).tick_width == 0.5);
    assert(adjustTickWidth(Axis(-0.1, 4), 8).min_tick == 0.0);
    assert(adjustTickWidth(Axis(0.1, 4), 8).min_tick == 0.5);
    assert(adjustTickWidth(Axis(1, 40), 8).min_tick == 5);
    assert(adjustTickWidth(Axis(3, 4), 5).min_tick == 3);
    assert(adjustTickWidth(Axis(3, 4), 5).tick_width == 0.2);
    assert(adjustTickWidth(Axis(1.79877e+07, 1.86788e+07), 5).min_tick == 1.8e+07);
    assert(adjustTickWidth(Axis(1.79877e+07, 1.86788e+07), 5).tick_width == 100_000);
}

private struct Ticks
{
    double currentPosition;
    Axis axis;

    @property double front()
    {
        import std.math : abs;
        if (currentPosition >= axis.max)
            return axis.max;
        // Special case for zero, because a small numerical error results in
        // wrong label, i.e. 0 + small numerical error (of 5.5e-17) is 
        // displayed as 5.5e-17, while any other numerical error falls 
        // away in rounding
        if (abs(currentPosition - 0) < axis.tick_width/1.0e5)
            return 0.0;
        return currentPosition;
    }

    void popFront()
    {
        if (currentPosition < axis.min_tick)
            currentPosition = axis.min_tick;
        else
            currentPosition += axis.tick_width;
    }

    @property bool empty()
    {
        if (currentPosition - axis.tick_width >= axis.max)
            return true;
        return false;
    }
}

/// Returns a range starting at axis.min, ending axis.max and with
/// all the tick locations in between
auto axisTicks(Axis axis)
{
    return Ticks(axis.min, axis);
}

unittest
{
    import std.array : array, front, back;

    auto ax1 = adjustTickWidth(Axis(0, .4), 5).axisTicks;
    auto ax2 = adjustTickWidth(Axis(0, 4), 8).axisTicks;
    assertEqual(ax1.array.front, 0);
    assertEqual(ax1.array.back, .4);
    assertEqual(ax2.array.front, 0);
    assertEqual(ax2.array.back, 4);
    assertGreaterThan(ax1.array.length, 3);
    assertLessThan(ax1.array.length, 8);

    assertGreaterThan(ax2.array.length, 5);
    assertLessThan(ax2.array.length, 10);

    auto ax3 = adjustTickWidth(Axis(1.1, 2), 5).axisTicks;
    assertEqual(ax3.array.front, 1.1);
    assertEqual(ax3.array.back, 2);
}

/// Calculate tick length
double tickLength(in Axis axis)
{
    return (axis.max - axis.min) / 25.0;
}

unittest
{
    auto axis = Axis(-1, 1);
    assert(tickLength(axis) == 0.08);
}

/// Convert a value to an axis label
string toAxisLabel( double value )
{
    import std.math : abs, round;
    import std.format : format;
    if (abs(value) > 1 && abs(value) < 100_000)
    {
        auto rv = round(value);
        auto dec = abs(round((value - rv)*100));
        if (dec == 0)
            return format( "%s", rv );
        else if (dec%10 == 0)
            return format( "%s.%s", rv, dec/10);
        else
            return format( "%s.%s", rv, dec);
    }
    return format( "%.3g", value );
}

unittest
{
    assertEqual( 5.toAxisLabel, "5" );
    assertEqual( (0.5).toAxisLabel, "0.5" );
    assertEqual( (0.001234567).toAxisLabel, "0.00123" );
    assertEqual( (0.00000001234567).toAxisLabel, "1.23e-08" );
    assertEqual( (2001).toAxisLabel, "2001" );
    assertEqual( (2001.125).toAxisLabel, "2001.13" );
    assertEqual( (-2001).toAxisLabel, "-2001" );
    assertEqual( (-2001.125).toAxisLabel, "-2001.13" );
    assertEqual( (-2.301).toAxisLabel, "-2.3" );
}

/// Aes describing the axis and its tick locations
auto axisAes(string type, double minC, double maxC, double lvl, Tuple!(double, string)[] ticks = [])
{
    import std.algorithm : sort, uniq, map;
    import std.array : array;
    import std.conv : to;
    import std.range : empty, repeat, take, popFront, walkLength;

    import ggplotd.aes : Aes;

    double[] ticksLoc;
    auto sortedAxisTicks = ticks.sort().uniq;

    string[] labels;

    if (!sortedAxisTicks.empty)
    {
        ticksLoc = [minC] ~ sortedAxisTicks.map!((t) => t[0]).array ~ [maxC];
        labels = [""] ~ sortedAxisTicks.map!((t) {
            if (t[1].empty)
                return t[0].to!double.toAxisLabel;
            else
                return t[1];
        }).array ~ [""];
    }
    else
    {
        ticksLoc = Axis(minC, maxC).adjustTickWidth(5).axisTicks.array;
        labels = ticksLoc.map!((a) => a.to!double.toAxisLabel).array;
    }

    if (type == "x")
    {
        return Aes!(double[], "x", double[], "y", string[], "label", double[], "angle")(
            ticksLoc, lvl.repeat().take(ticksLoc.walkLength).array, labels,
            (0.0).repeat(labels.walkLength).array);
    }
    else
    {
        import std.math : PI;

        return Aes!(double[], "x", double[], "y", string[], "label", double[], "angle")(
            lvl.repeat().take(ticksLoc.walkLength).array, ticksLoc, labels,
            ((-0.5 * PI).to!double).repeat(labels.walkLength).array);
    }
}

unittest
{
    import std.stdio : writeln;

    auto aes = axisAes("x", 0.0, 1.0, 2.0);
    assertEqual(aes.front.x, 0.0);
    assertEqual(aes.front.y, 2.0);
    assertEqual(aes.front.label, "0");

    aes = axisAes("y", 0.0, 1.0, 2.0, [Tuple!(double, string)(0.2, "lbl")]);
    aes.popFront;
    assertEqual(aes.front.x, 2.0);
    assertEqual(aes.front.y, 0.2);
    assertEqual(aes.front.label, "lbl");
}

private string ctReplaceAll( string orig, string pattern, string replacement )
{

    import std.string : split;
    auto spl = orig.split( pattern );
    string str = spl[0];
    foreach( sp; spl[1..$] )
        str ~= replacement ~ sp;
    return str;
}

// Create a specialised x and y axis version of a given function.
private string xy( string func )
{
    import std.format : format;
    return format( "///\n%s\n\n///\n%s",
        func
            .ctReplaceAll( "axis", "xaxis" )
            .ctReplaceAll( "Axis", "XAxis" ),
        func
            .ctReplaceAll( "axis", "yaxis" )
            .ctReplaceAll( "Axis", "YAxis" ) );
}

alias XAxisFunction = XAxis delegate(XAxis);
alias YAxisFunction = YAxis delegate(YAxis);

// Below are the external functions to be used by library users.

// Set the range of an axis
mixin( xy( q{auto axisRange( double min, double max ) 
{ 
    AxisFunction func = ( Axis axis ) { axis.min = min; axis.max = max; return axis; }; 
    return func;
}} ) );

///
unittest
{
    XAxis ax;
    auto f = xaxisRange( 0, 1 );
    assertEqual( f(ax).min, 0 );
    assertEqual( f(ax).max, 1 );

    YAxis yax;
    auto yf = yaxisRange( 0, 1 );
    assertEqual( yf(yax).min, 0 );
    assertEqual( yf(yax).max, 1 );
}

// Set the label of an axis
mixin( xy( q{auto axisLabel( string label ) 
{ 
    // Need to declare it as an X/YAxisFunction for the GGPlotD + overload
    AxisFunction func = ( Axis axis ) { axis.label = label; return axis; }; 
    return func;
}} ) );

///
unittest
{
    XAxis xax;
    auto xf = xaxisLabel( "x" );
    assertEqual( xf(xax).label, "x" );

    YAxis yax;
    auto yf = yaxisLabel( "y" );
    assertEqual( yf(yax).label, "y" );
}

// Set the range of an axis
mixin( xy( q{auto axisOffset( double offset ) 
{ 
    AxisFunction func = ( Axis axis ) { axis.offset = offset; return axis; }; 
    return func;
}} ) );

///
unittest
{
    XAxis xax;
    auto xf = xaxisOffset( 1 );
    assertEqual( xf(xax).offset, 1 );

    YAxis yax;
    auto yf = yaxisOffset( 2 );
    assertEqual( yf(yax).offset, 2 );
}


