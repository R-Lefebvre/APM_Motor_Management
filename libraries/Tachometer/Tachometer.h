#ifndef TACHOMETER
#define TACHOMETER

#define TACH_LOW_SPEED               0
#define TACH_HIGH_SPEED              1

class Tachometer {

    float calc_rpm_slow();
    float calc_rpm_fast();

    volatile unsigned long trigger_time;        // Trigger time of latest interrupt
    volatile int trigger_counts;
    int trigger_count_accumulator[10];
    unsigned int pulses_per_revolution;
    int tach_speed;
    volatile unsigned long trigger_time_old;    // Trigger time of last interrupt
    unsigned long trigger_last_calc_time;       // Trigger time of last speed calculated
    unsigned long trigger_timing;               // timing of last rotation
    unsigned long trigger_timing_old;           // Old rotation timing
    unsigned int trigger_pulses_per_rev;
    float rpm_measured_fast;                    // Latest measured RPM value for fast tach input
    float rpm_measured_slow;                    // Latest measured RPM value for slow tach input
    bool timing_overflow_trigger_skip;          // Bit used to signal micros() timer overflowed
                                                // We set true to start so that we will throw out
                                                // the first data point collected after booting
                                                // because it is flaky.

    public:
        
        Tachometer(int,int,int);                // Constructor
        void check_pulses(unsigned long);
        void count_pulses();
        void timer_overflow_handler();
        void interrupt_function();
        float get_rpm();
};

#endif //TACHOMETER