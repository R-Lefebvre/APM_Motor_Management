/// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

#define THISFIRMWARE "APM_Motor_Management V0.1"
#include <i2c_t3.h>

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

#include <Tachometer.h>         //Tachometer class definition
#include <Temperature.h>        //Temperature sensor class definition

#define ENABLED                 1
#define DISABLED                0

#define LOW_SPEED               0
#define HIGH_SPEED              1

#define Serial_Debug            ENABLED

#define BoardLED                13
#define RPM_INPUT_1             6
#define RPM_INPUT_2             7
#define RPM_INPUT_3             8
#define RPM_INPUT_4             9
#define TEMP_INPUT_1            16
#define TEMP_INPUT_2            17

#define D_BUFF_PPM_1            0
#define D_BUFF_PPM_2            1
#define D_BUFF_PPM_3            2
#define D_BUFF_PPM_4            3
#define D_BUFF_TEMP_1           4
#define D_BUFF_TEMP_2           5
#define NUM_FLOATS              6
#define BYTES_PER_FLOAT         4

#define MM_I2C_SLAVE_ADDRESS    0x36
#define FIRST_REG_ADDRESS       0x20
#define REQUEST_PPM_1           0x20
#define REQUEST_PPM_2           0x21
#define REQUEST_PPM_3           0x22
#define REQUEST_PPM_4           0x23
#define REQUEST_TEMP_1          0x24
#define REQUEST_TEMP_2          0x25


bool LedBlinker = true;

uint32_t    super_fast_loop_timer = 0;          // Time in microseconds of 1000hz control loop
uint32_t    last_super_fast_loop_timer = 0;     // Time in microseconds of the previous fast loop
uint32_t    fast_loop_timer = 0;                // Time in milliseconds of 100hz control loop
uint32_t    last_fast_loop_timer = 0;           // Time in milliseconds of the previous loop, used to calculate dt
uint8_t     fast_loop_dt = 0;                   // Time since the last 100hz loop.
uint32_t    medium_loop_timer = 0;              // Time in milliseconds of 50hz control loop
uint32_t    last_medium_loop_timer = 0;         // Time in milliseconds of the previous loop, used to calculate dt
uint8_t     medium_loop_dt= 0 ;                 // Time since the last 50 Hz loop
uint32_t    slow_loop_timer = 0;                // Time in milliseconds of the 10hz control loop
uint32_t    super_slow_loop_timer = 0;          // Time in milliseconds of the 1hz control loop

Tachometer tach1(RPM_INPUT_1, LOW_SPEED);
Tachometer tach2(RPM_INPUT_2, LOW_SPEED);
Tachometer tach3(RPM_INPUT_3, HIGH_SPEED);
Tachometer tach4(RPM_INPUT_4, HIGH_SPEED);

Temperature temp1(TEMP_INPUT_1);
Temperature temp2(TEMP_INPUT_2);

union D_Buff {uint8_t D_Buff_byte[NUM_FLOATS * BYTES_PER_FLOAT]; float D_Buff_float[NUM_FLOATS];} D_Buff_Union;
volatile uint8_t I2C_Reg_Req_Num = 0;
volatile uint8_t I2C_Bytes_Req = 0;
uint8_t info_index = 0;
uint8_t register_index = 0;
uint8_t register_index_perm = 0;
uint8_t register_index_stop = 0;

// Function prototypes
void receiveEvent(size_t len);
void requestEvent(void);

void setup(){

    attachInterrupt(RPM_INPUT_1, interrupt_1_function, RISING);
    attachInterrupt(RPM_INPUT_2, interrupt_2_function, RISING);
    attachInterrupt(RPM_INPUT_3, interrupt_3_function, RISING);
    attachInterrupt(RPM_INPUT_4, interrupt_4_function, RISING);
    pinMode(BoardLED, OUTPUT);

    Wire.begin(MM_I2C_SLAVE_ADDRESS);
    Wire.onRequest(requestEvent);
    Wire.onReceive(receiveEvent);

#if Serial_Debug == ENABLED
    serial_debug_init();
#endif
}

void loop(){

uint32_t timer = millis();                         // Time in milliseconds of current loop

    if (( micros() - super_fast_loop_timer) >= 1000){
        super_fast_loop_timer = micros();
        if (!micros_overflow()){
            superfastloop();
        } else {
            tach1.timer_overflow_handler();
            tach2.timer_overflow_handler();
        }
        last_super_fast_loop_timer = super_fast_loop_timer;
    }

    if ((timer - fast_loop_timer) >= 10) {
        last_fast_loop_timer = fast_loop_timer;
        fast_loop_timer = timer;
        fast_loop_dt = last_fast_loop_timer - fast_loop_timer;
        fastloop();
    }

    if ((timer - medium_loop_timer) >= 20) {
        last_medium_loop_timer = medium_loop_timer;
        medium_loop_timer = timer;
        medium_loop_dt = last_medium_loop_timer - medium_loop_timer;
        mediumloop();
    }
    
    if ((timer - slow_loop_timer) >= 100) {
        slow_loop_timer = timer;
        slowloop();
    }

    if ((timer - super_slow_loop_timer) >= 1000) {
        super_slow_loop_timer = timer;
        superslowloop();
    }
}

void superfastloop(){            //1000hz stuff goes here

    tach1.check_pulses(super_fast_loop_timer);
    tach2.check_pulses(super_fast_loop_timer);
    tach3.check_pulses(super_fast_loop_timer);
    tach4.check_pulses(super_fast_loop_timer);
}

void fastloop(){                    //100hz stuff goes here

    tach1.count_pulses();
    tach2.count_pulses();
    tach3.count_pulses();
    tach4.count_pulses();
    temp1.take_reading();
    temp2.take_reading();
}

void mediumloop(){                  //50hz stuff goes here

    D_Buff_Union.D_Buff_float[D_BUFF_PPM_1] = tach1.get_rpm();
    D_Buff_Union.D_Buff_float[D_BUFF_PPM_2] = tach2.get_rpm();
    D_Buff_Union.D_Buff_float[D_BUFF_PPM_3] = tach3.get_rpm();
    D_Buff_Union.D_Buff_float[D_BUFF_PPM_4] = tach4.get_rpm();
}

void slowloop(){                    //10hz stuff goes here

    D_Buff_Union.D_Buff_float[D_BUFF_TEMP_1] = temp1.get_temp_V();
    D_Buff_Union.D_Buff_float[D_BUFF_TEMP_2] = temp2.get_temp_V();
}

void superslowloop(){               //1hz stuff goes here

    if (LedBlinker){
        digitalWrite(BoardLED, HIGH);   // sets the LED on
        LedBlinker = false;
    } else if (!LedBlinker){
        digitalWrite(BoardLED, LOW);
        LedBlinker = true;
    }

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

void receiveEvent(size_t bytes)
{
    while( Wire.available() ){
        I2C_Reg_Req_Num = Wire.read();
        I2C_Bytes_Req = Wire.read();
    }

    info_index = I2C_Reg_Req_Num - FIRST_REG_ADDRESS;
    register_index = info_index*BYTES_PER_FLOAT;
	register_index_perm = register_index;
    register_index_stop = register_index + I2C_Bytes_Req;
}

void requestEvent()
{
     while(register_index < register_index_stop){
        Wire.write(D_Buff_Union.D_Buff_byte[register_index]);
        register_index++;
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
    Serial.print ("PPM 1: ");
    Serial.print(D_Buff_Union.D_Buff_float[D_BUFF_PPM_1]);
    Serial.print (" 2: ");
    Serial.print(D_Buff_Union.D_Buff_float[D_BUFF_PPM_2]);
    Serial.print (" 3: ");
    Serial.print(D_Buff_Union.D_Buff_float[D_BUFF_PPM_3]);
    Serial.print (" 4: ");
    Serial.print(D_Buff_Union.D_Buff_float[D_BUFF_PPM_4]);
    Serial.print (" Temp 1: ");
    Serial.print (D_Buff_Union.D_Buff_float[D_BUFF_TEMP_1]);
    Serial.print (" Temp 2: ");
    Serial.println (D_Buff_Union.D_Buff_float[D_BUFF_TEMP_2]);

    Serial.print ("Received: ");
    Serial.print (I2C_Reg_Req_Num);
    Serial.print (" ");
    Serial.println (I2C_Bytes_Req);

    Serial.print ("Info Index: ");
    Serial.print (info_index);
    Serial.print (" Register Index: ");
    Serial.print (register_index_perm);
    Serial.print (" Stop Index: ");
    Serial.println (register_index_stop);
    Serial.println (" ");
}

// Wrappers for ISR functions
void interrupt_1_function(){
    tach1.interrupt_function();
}

void interrupt_2_function(){
    tach2.interrupt_function();
}

void interrupt_3_function(){
    tach3.interrupt_function();
}

void interrupt_4_function(){
    tach4.interrupt_function();
}

#endif