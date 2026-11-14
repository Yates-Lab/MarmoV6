//Arduino script for setting pins based on a serial input, 
//important to be able to sent them independantly with bit masking
// Might want to also put in a state call so marmoview can get current state

// Calculate based on max input size expected for one command
#define INPUT_SIZE 30

char state[5] ={'n','u','l','l','\0'}; // four char points, one for each pin, for printing and debugging 


void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  Serial.println("begin");

  // pins 10-13 map to smallest to largest, pin 10 is 'first' least significant bit 0001 
  pinMode(13, OUTPUT);    // sets the digital pin 13 as output
  pinMode(12, OUTPUT);    // sets the digital pin 12 as output
  pinMode(11, OUTPUT);    // sets the digital pin 11 as output
  pinMode(10, OUTPUT);    // sets the digital pin 10 as output
  
  //initialise low
  digitalWrite(11,0);
  digitalWrite(11,0);
  digitalWrite(11,0);
  digitalWrite(11,0);

}

void loop() {
  state[5]=0;
  if (Serial.available() > 0)
  {
    // put your main code here, to run repeatedly:


    // Get next command from Serial (add 1 for final 0)
    char input[INPUT_SIZE + 1];
    byte size = Serial.readBytes(input, INPUT_SIZE);
    // Add the final 0 to end the C string
    input[size] = 0;


    //Example string 'Value:16,Bitmask:0001,'
    // want to split into two pairs, then into name,value 

    // Read each pair, split on tab
    char* Valuename = strtok(input, ":");
    //Serial.println(Valuename);
    char* Valuestr = strtok(0, ",");
    //Serial.println(Valuestr);
    
    char* Maskname = strtok(0, ":");
    //Serial.println(Maskname);
    char* Maskstring = strtok(0, ",");
    //Serial.println(Maskstring);

    double value =atoi(Valuestr); 
    int Maskedloc[4];
    int nbits = 0;
    int i = 0;
    for (i=0; i< 4; i++)
    {
        if (Maskstring[i]=='1'){
          Maskedloc[nbits]=i;
          //Serial.println(Maskedloc[nbits]);
          nbits ++;
        }   
    }

    double maxvalue = 0;
    maxvalue=pow(2,double(nbits))-1;//maximum value to set
    if (value>maxvalue) //set all masked bits high
    {
      value=maxvalue;
    }
   

    int bit =0;
    double valuecheck = 0;
    bool valuebit =0;
    int setbit;
    //change value (in dec) to bits in a str to save sanity
    for (bit=0; bit< nbits; bit++)
    {
        //check if decimal is higher than this: (2^(nbits-bit-1)); 0123 8421
        valuecheck = pow(2,nbits-bit-1)-0.001;
        //valuebit = ~(double(value)>=valuecheck);
        valuebit = value>=valuecheck;

        //Serial.print("NewValue: ");
        //Serial.println((value));
        //Serial.print("Threshold: ");
        //Serial.println((valuecheck));
        //Serial.print("Bool: ");
        //Serial.println((valuebit));    
         
        if (valuebit==1){
          //set bit high
          value=value-valuecheck;
          setbit=1;
        }else{
          //set bit low
          setbit=0;
        }


        //Set digital bits//pin, value
        switch (Maskedloc[bit]) {
          case 0:
          //4th pin, 1000,
            digitalWrite(13,setbit);
            itoa(setbit,&state[0],10);
            break;
          case 1:
          //3rd pin, 0100,
            digitalWrite(12,setbit);
            itoa(setbit,&state[1],10);
            break;
          case 2:
          //2nd pin, 0010,
            digitalWrite(11,setbit);
            itoa(setbit,&state[2],10);
            break;
          case 3:
          //1st pin, 0001,
            digitalWrite(10,setbit);
            itoa(setbit,&state[3],10);
            break;
        }
        //Serial.print("Location: ");
        //Serial.println((Maskedloc[bit])); 
        //Serial.print("Set: ");
        //Serial.println((setbit));  
        
    }

  //TODO, Make this MarmoV6 compatible, sending a reply without reading in matlab messes with blocking on receiving 
  //Serial.print("State on all pins: ");
 // Serial.println((state));

  }
}