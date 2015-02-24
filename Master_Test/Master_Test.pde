//i2c Master Code(UNO)
#include <Wire.h>

#define MM_I2C_SLAVE_ADDRESS    0x36
#define REQUEST_PPM_1           0x20
#define REQUEST_PPM_2           0x21
#define REQUEST_PPM_3           0x22
#define REQUEST_PPM_4           0x23

float PPM;
union PPM_tag {byte PPM_b[4]; float PPM_fval;} PPM_Union;    

void setup()
{
  Serial.begin(9600);
  Wire.begin();
}

void loop()
{
    for (int i = 1; i < 5; i++){
        request_data(i);
        Serial.print ("PPM ");
        Serial.print (i);
        Serial.print (": ");
        Serial.print (PPM);
        Serial.print (" ");
    }
    Serial.println (" ");    
    delay(1000);
}

void request_data(int ppm_num){
    int I2C_Reg_Num;
    switch (ppm_num){
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
            I2C_Reg_Num = 0;
    }
    Wire.beginTransmission(5);
    Wire.write(I2C_Reg_Num);
    Wire.requestFrom(5,4);
    for (int i = 0; i < 4; i++){
        PPM_Union.PPM_b[i] = Wire.read();          // receive a byte as character
    }
    PPM = PPM_Union.PPM_fval;
    Wire.endTransmission();

}