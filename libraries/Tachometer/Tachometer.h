#ifndef TACHOMETER
#define TACHOMETER

#include "inttypes.h"

#define TACH_LOW_SPEED               0
#define TACH_HIGH_SPEED              1

class Tachometer {

    float calc_rpm_slow();
    float calc_rpm_fast();

    volatile uint32_t trigger_time;        // Trigger time of latest interrupt
    volatile uint16_t trigger_counts;
    uint16_t trigger_count_accumulator[10];
    uint16_t pulses_per_revolution;
    uint16_t tach_speed;
    volatile uint32_t trigger_time_old;    // Trigger time of last interrupt
    uint32_t trigger_last_calc_time;       // Trigger time of last speed calculated
    uint32_t trigger_timing;               // timing of last rotation
    uint32_t trigger_timing_old;           // Old rotation timing
     uint16_t trigger_pulses_per_rev;
    float rpm_measured_fast;                    // Latest measured RPM value for fast tach input
    float rpm_measured_slow;                    // Latest measured RPM value for slow tach input
    bool timing_overflow_trigger_skip;          // Bit used to signal micros() timer overflowed
                                                // We set true to start so that we will throw out
                                                // the first data point collected after booting
                                                // because it is flaky.

    public:
        
        Tachometer(uint16_t,uint16_t,uint16_t);                // Constructor
        void check_pulses(uint32_t);
        void count_pulses();
        void timer_overflow_handler();
        void interrupt_function();
        float get_rpm();
};

#endif //TACHOMETER