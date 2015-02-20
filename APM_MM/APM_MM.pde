/// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

#define THISFIRMWARE "APM_Motor_Management V0.1"

/*
APM_Motor_Management V0.1
Lead author:    Robert Lefebvre

This firmware is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This program is intended to operate with a maximum rotorspeed of 4000rpm.
4000rpm = 66.667rev/sec = 0.015sec/rev = 15ms/rev = 15000uS/rev
Also:
800rpm = 13.333rev/sec = 0.075sec/rev = 75ms/rev = 75000uS/rev

1ms accuracy would give between 10 and 250rpm resolution which is not acceptable
Thus, we must use microseconds to measure RPM.
Atmega chip operating at 16MHz has 4uS resolution, 8MHz gives 8uS resolution. 
4uS resolution will give an RPM resolution of ~ 0.05 to 1 rpm.
Better than 0.025% accuracy!

Maximum intended motor RPM is 50,000 representing a 450 heli running 4S battery
50000rpm = 833rev/sec = 0.0012sec/rev = 1200uS/rev
4uS accuracy would give 166rpm accuracy, or 0.3%.

micros() counter will overflow after ~70 minutes, we must protect for that
to avoid an error or blip in the speed reading.

Measurement Type can be either Direct_Measurement, meaning actual
propeller measurement.  Or it can be Motor_Measurement.  Motor_Measurement
requires input of number of poles, and gear ratio.

*/

#define ENABLED                 1
#define DISABLED                0

#define Serial_Debug            ENABLED

#define BoardLED                11
#define RPM_INPUT_1             0
#define RPM_INPUT_2             1
#define TRIGGER_PPR_DEFAULT     1

unsigned long fast_loop_timer = 0;              // Time in microseconds of 1000hz control loop
unsigned long last_fast_loop_timer = 0;         // Time in microseconds of the previous fast loop
unsigned long fiftyhz_loop_timer = 0;           // Time in milliseconds of 50hz control loop
unsigned long last_fiftyhz_loop_timer = 0;      // Time in milliseconds of the previous loop, used to calculate dt
unsigned int fiftyhz_dt= 0 ;                    // Time since the last 50 Hz loop
unsigned long tenhz_loop_timer = 0;             // Time in milliseconds of the 10hz control loop
unsigned long onehz_loop_timer = 0;             // Time in milliseconds of the 1hz control loop

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

Tachometer tach1(RPM_INPUT_1, TRIGGER_PPR_DEFAULT);
Tachometer tach2(RPM_INPUT_2, TRIGGER_PPR_DEFAULT);

void setup(){

    attachInterrupt(RPM_INPUT_1, interrupt_1_function, RISING);
    attachInterrupt(RPM_INPUT_2, interrupt_2_function, RISING);

#if Serial_Debug == ENABLED
    serial_debug_init();
#endif
}

void loop(){

unsigned long timer = millis();                         // Time in milliseconds of current loop

    if (( micros() - fast_loop_timer) >= 1000){
        fast_loop_timer = micros();
        if (!micros_overflow()){
            fastloop();
        } else {
            tach1.timer_overflow_handler();
            tach2.timer_overflow_handler();
        }
        last_fast_loop_timer = fast_loop_timer;
    }

    if ((timer - fiftyhz_loop_timer) >= 20) {
        last_fiftyhz_loop_timer = fiftyhz_loop_timer;
        fiftyhz_loop_timer = timer;
        fiftyhz_dt = last_fiftyhz_loop_timer - fiftyhz_loop_timer;
        mediumloop();
    }
    
    if ((timer - tenhz_loop_timer) >= 10) {
        tenhz_loop_timer = timer;
        slowloop();
    }

    if ((timer - onehz_loop_timer) >= 1000) {
        onehz_loop_timer = timer;
        superslowloop();
    }
}

void fastloop(){            //1000hz stuff goes here
    tach1.check_pulses(fast_loop_timer);
    tach2.check_pulses(fast_loop_timer);   
}

void mediumloop(){                  //50hz stuff goes here
    digitalWrite(BoardLED, LOW);
}

void slowloop(){                    //10hz stuff goes here

}

void superslowloop(){               //1hz stuff goes here
#if Serial_Debug == ENABLED
    do_serial_debug();
#endif
}

///////////////////////////////////////////////////////////////////////////////////////////////////
/*
The micros() timer will overflow roughly ever 70 minutes.  This is within the possible operating
time of a UAV so we must protect for it.  When the micros() timer overflows, we must
ignore any data collected during the period.
*/
///////////////////////////////////////////////////////////////////////////////////////////////////

bool micros_overflow(){
    if (micros() > last_fast_loop_timer) {              // Micros() have not overflowed because it has incremented since last fast loop
        return false;
    } else {
        return true;
    }
}

#if Serial_Debug == ENABLED

void serial_debug_init(){
    Serial.begin(9600);
    Serial.println("Tachometer Test");
    Serial.print("Startup Micros:");
    Serial.println(micros());
}

void do_serial_debug(){
    Serial.print ("RPM 1 =");
    Serial.println(tach1.get_rpm());
    Serial.print ("RPM 2 =");
    Serial.println(tach2.get_rpm());
}

// Wrappers for ISR functions
void interrupt_1_function(){
    tach1.interrupt_function();
}

void interrupt_2_function(){
    tach2.interrupt_function();
}

#endif