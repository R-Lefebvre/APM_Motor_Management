//i2c Master Code(UNO)
#include <Wire.h>

#define ENABLED                 1
#define DISABLED                0

#define SERIAL_DEBUG            ENABLED

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

#define TEMP_1_SENSOR_ZERO      0
#define TEMP_2_SENSOR_ZERO      0.5
#define TEMP_1_SENSOR_SCALE     0.010
#define TEMP_2_SENSOR_SCALE     0.010

#define PULSES_PER_REV          3

bool        get_single_words = DISABLED;
bool        have_I2C_data = false;                                  // flag used to signal we have data back from I2C
uint8_t     I2C_data_request = 0;                                   // indicates which piece of data we are seeking currently
uint16_t    I2C_Reg_Num = 0;                                        // register of I2C Slave containing information we are seeking
uint16_t    num_bytes_I2C = 0;                                      // Number of bytes to request from I2C

// Data returned from I2C Slave
union D_Buff {uint8_t D_Buff_byte[NUM_FLOATS * BYTES_PER_FLOAT]; float D_Buff_float[NUM_FLOATS];} D_Buff_Union;

uint16_t last_micros = 0;
uint16_t elapsed_micros =0;

void setup()
{
    Serial.begin(57600);
    Wire.begin();
}

void loop()
{

    if(get_single_words){
        get_data_single_words();
    }else{
        get_data_all_words();
    }

}

void request_I2C_data(){
    Wire.beginTransmission(MM_I2C_SLAVE_ADDRESS);
    Wire.write(I2C_Reg_Num);
    Wire.write(num_bytes_I2C);
    Wire.endTransmission();
    Wire.requestFrom(MM_I2C_SLAVE_ADDRESS,num_bytes_I2C);
    for (uint16_t i = 0; i < num_bytes_I2C; i++){
        D_Buff_Union.D_Buff_byte[i] = Wire.read();                   // receive a byte as character
    }
    have_I2C_data = true;
}

void get_data_all_words(){
    if (have_I2C_data){
#if SERIAL_DEBUG == ENABLED
        Serial.print ("PPM 1:");
        Serial.print (D_Buff_Union.D_Buff_float[D_BUFF_PPM_1]);
        Serial.print (" 2:");
        Serial.print (D_Buff_Union.D_Buff_float[D_BUFF_PPM_2]);
        Serial.print (" 3:");
        Serial.print (D_Buff_Union.D_Buff_float[D_BUFF_PPM_3]/PULSES_PER_REV);
        Serial.print (" 4:");
        Serial.print (D_Buff_Union.D_Buff_float[D_BUFF_PPM_4]/PULSES_PER_REV);
        Serial.print (" Temp 1:");
        Serial.print ((D_Buff_Union.D_Buff_float[D_BUFF_TEMP_1]-TEMP_1_SENSOR_ZERO)/TEMP_1_SENSOR_SCALE);
        Serial.print (" Temp 2:");
        Serial.print ((D_Buff_Union.D_Buff_float[D_BUFF_TEMP_2]-TEMP_2_SENSOR_ZERO)/TEMP_2_SENSOR_SCALE);
#endif // SERIAL_DEBUG
        have_I2C_data = false;
    } else {
        elapsed_micros = micros() - last_micros;
        last_micros = micros();
#if SERIAL_DEBUG == ENABLED
        Serial.print(" Cycle Time: ");
#endif // SERIAL_DEBUG
        Serial.println(elapsed_micros);
        I2C_Reg_Num = FIRST_REG_ADDRESS;
        num_bytes_I2C = NUM_FLOATS * BYTES_PER_FLOAT;
        request_I2C_data();
    }
}


void get_data_single_words(){
    if (have_I2C_data){
#if SERIAL_DEBUG == ENABLED
        Serial.print (I2C_data_request);
        Serial.print (": ");
        Serial.print (D_Buff_Union.D_Buff_float[0]);
        Serial.print (" ");
#endif // SERIAL_DEBUG
        I2C_data_request++;
        if (I2C_data_request > 4){
            I2C_data_request = 0;
        }
        have_I2C_data = false;
    } else {
        switch (I2C_data_request){
            case 1:
                I2C_Reg_Num = REQUEST_PPM_1;
                break;
            case 2:
                I2C_Reg_Num = REQUEST_PPM_2;
                break;
            case 3:
                I2C_Reg_Num = REQUEST_PPM_3;
                break;
            case 4:
                I2C_Reg_Num = REQUEST_PPM_4;
                break;
            case 5:
                I2C_Reg_Num = REQUEST_TEMP_1;
                break;
            case 6:
                I2C_Reg_Num = REQUEST_TEMP_2;
                break;
            default:
                elapsed_micros = micros() - last_micros;
                last_micros = micros();
#if SERIAL_DEBUG == ENABLED
                Serial.print("Cycle Time: ");
#endif // SERIAL_DEBUG
                Serial.println(elapsed_micros);
#if SERIAL_DEBUG == ENABLED
                Serial.print ("Data_f ");
#endif // SERIAL_DEBUG
                I2C_data_request = 1;
                num_bytes_I2C = 4;
                return;
        }
        request_I2C_data();
    }
}