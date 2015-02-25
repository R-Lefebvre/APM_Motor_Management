#ifndef TACHOMETER
#define TACHOMETER

#include "inttypes.h"

#define TACH_LOW_SPEED               0
#define TACH_HIGH_SPEED              1

class Tachometer {

    public:
        // Methods
        Tachometer(uint16_t,uint16_t);              // Constructor
        void    check_pulses(uint32_t);             // Call at 1000 Hz to check for new pulses, allows max PPM of 60,000
        void    count_pulses();                     // Call at 100 Hz to accumulate high speed pulses
        void    timer_overflow_handler();           // Manages millis() overflow which upsets timing data
        void    interrupt_function();               // What to do on a timer capture ISR
        float   get_rpm();                          // Call to return RPM value

    private:
        // Methods
        float calc_ppm_slow();                      // Method to calculate rpm on slow channel
        float calc_ppm_fast();                      // Method to calculate rpm on fast channel

        // Members
        volatile uint32_t   _trigger_time;                  // Trigger time of latest interrupt
        volatile uint16_t   _trigger_counts;                // Accumulated trigger counts
        uint16_t            _trigger_count_accumulator[10]; // Accumulator for moving-average filter
        uint16_t            _tach_speed;                    // Set speed of tach object low, or high for greater that 60,000 PPM
        volatile uint32_t   _trigger_time_old;              // Trigger time of last interrupt
        uint32_t            _trigger_timing;                // timing of last rotation
        uint32_t            _trigger_timing_old;            // Old rotation timing
        float               _ppm_measured_slow;             // Latest measured RPM value for slow tach input
        bool                _timing_overflow_trigger_skip;  // Bit used to signal micros() timer overflowed
                                                            // We set true to start so that we will throw out
                                                            // the first data point collected after booting
                                                            // because it is flaky.

};

#endif //TACHOMETER