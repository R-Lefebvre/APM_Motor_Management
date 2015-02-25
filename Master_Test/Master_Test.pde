//i2c Master Code(UNO)
#include <Wire.h>

#define ENABLED                 1
#define DISABLED                0

#define SERIAL_DEBUG            ENABLED

#define MM_I2C_SLAVE_ADDRESS    0x36
#define REQUEST_PPM_1           0x20
#define REQUEST_PPM_2           0x21
#define REQUEST_PPM_3           0x22
#define REQUEST_PPM_4           0x23

bool have_I2C_data = false;                                 // flag used to signal we have data back from I2C
byte I2C_data_request = 0;                                  // indicates which piece of data we are seeking currently
int I2C_Reg_Num = 0;                                        // register of I2C Slave containing information we are seeking
float PPM = 0.0;                                            // PPM data returned from I2C Slave
union PPM_tag {byte PPM_b[4]; float PPM_fval;} PPM_Union;   // Union to combine I2C bytes into float

int last_micros = 0;
int elapsed_micros =0;

void setup()
{
    Serial.begin(57600);
    Wire.begin();
}

void loop()
{
    if (have_I2C_data){
#if SERIAL_DEBUG == ENABLED
        Serial.print (I2C_data_request);
        Serial.print (": ");
        Serial.print (PPM);
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
            default:
                elapsed_micros = micros() - last_micros;
                last_micros = micros();
#if SERIAL_DEBUG == ENABLED
                Serial.print("Cycle Time: ");
#endif // SERIAL_DEBUG
                Serial.println(elapsed_micros);
#if SERIAL_DEBUG == ENABLED
                Serial.println (" ");
                Serial.print ("PPM ");
#endif // SERIAL_DEBUG
                I2C_data_request = 1;
                return;
        }
        request_I2C_data();
    }
}

void request_I2C_data(){
    Wire.beginTransmission(MM_I2C_SLAVE_ADDRESS);
    Wire.write(I2C_Reg_Num);
    Wire.endTransmission();
    Wire.requestFrom(MM_I2C_SLAVE_ADDRESS,4);
    for (int i = 0; i < 4; i++){
        PPM_Union.PPM_b[i] = Wire.read();          // receive a byte as character
    }
    PPM = PPM_Union.PPM_fval;
    have_I2C_data = true;
}