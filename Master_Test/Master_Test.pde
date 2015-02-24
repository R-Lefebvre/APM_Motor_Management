//i2c Master Code(UNO)
#include <Wire.h>

float PPM;
union PPM_tag {byte PPM_b[4]; float PPM_fval;} PPM_Union;    

void setup()
{
  Serial.begin(9600);
  Wire.begin();
}

void loop()
{
    Wire.beginTransmission(5);
    Wire.write(0x20);
    Wire.requestFrom(5,4);

    for (int i = 0; i < 4; i++){
        PPM_Union.PPM_b[i] = Wire.read();          // receive a byte as character
    }

    PPM = PPM_Union.PPM_fval;

    Wire.endTransmission();

    Serial.print ("PPM 1:");
    Serial.println(PPM);
    delay(1000);
}