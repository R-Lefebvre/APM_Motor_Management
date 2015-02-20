#include <Tachometer.h>
#include <Arduino.h>

Tachometer::Tachometer(int pin_assignment, int ppr){
    pulses_per_revolution = ppr;
    pinMode(pin_assignment, INPUT_PULLUP);
}

void Tachometer::interrupt_function(){
    trigger_time = micros();
}    

float Tachometer::calc_rpm(){
    return (rpm_measured + (60000000.0/(float)trigger_timing)/pulses_per_revolution)/2 ;        //Simple Low-pass Filter
}

void Tachometer::timer_overflow_handler(){
    //we will throw out whatever data we have
    trigger_time_old = 0;
    trigger_time = 0;

    //and the next capture too
    timing_overflow_trigger_skip == true;
}

void Tachometer::check_pulses(unsigned long fl_timer){
    if ( (trigger_time_old + (3 * trigger_timing)) < fl_timer ){        // We have lost more than 1 expected pulse, start to decay the measured RPM
        rpm_measured -= 0.25;
        if (rpm_measured <0){
            rpm_measured = 0;
        }
    }

    if (trigger_time_old != trigger_time){                              // We have new trigger_1_timing data to consume
        if (!timing_overflow_trigger_skip){                             // If micros has not overflowed, we will calculate trigger_1_timing based on this data
            trigger_timing_old = trigger_timing;
            trigger_timing = trigger_time - trigger_time_old;
            rpm_measured = calc_rpm();
        } else {
            timing_overflow_trigger_skip = false;                       // If micros has overflowed, reset the skip bit since we have thrown away this bad data
        }
        trigger_time_old = trigger_time;                                // In either case, we need to do this so we can look for new data		
    }
}