#ifndef TACHOMETER
#define TACHOMETER

class Tachometer {

    float calc_rpm();

    volatile unsigned long trigger_time;        // Trigger time of latest interrupt
    unsigned int pulses_per_revolution;
    volatile unsigned long trigger_time_old;    // Trigger time of last interrupt
    unsigned long trigger_last_calc_time;       // Trigger time of last speed calculated
    unsigned long trigger_timing;               // timing of last rotation
    unsigned long trigger_timing_old;           // Old rotation timing
    unsigned int trigger_pulses_per_rev;
    float rpm_measured;                         // Latest measured RPM value for input
    bool timing_overflow_trigger_skip;          // Bit used to signal micros() timer overflowed
                                                // We set true to start so that we will throw out
                                                // the first data point collected after booting
                                                // because it is flaky.

    public:
        
        Tachometer(int,int);                            // Constructor
        void check_pulses(unsigned long);
        void timer_overflow_handler();
        void interrupt_function();
        float get_rpm(){return rpm_measured;}        
};

#endif //TACHOMETER