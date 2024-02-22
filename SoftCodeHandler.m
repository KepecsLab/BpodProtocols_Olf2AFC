function SoftCodeHandler(softCode)
%soft codes 1-10 reserved for odor delivery
%soft code 11-20 reserved for PulsePal sound delivery
%soft code 21-30 reserved for PulsePal frequency delivery
%soft code 31-40 reserved for laser stimulation protocols

global BpodSystem
global TaskParameters

if softCode < 11 %for olfactory
    if BpodSystem.Data.Custom.OlfactometerStartup %if there has been a non-auditory trial and thus olfactometer initialized
        
        firstbank = ['Bank' num2str(TaskParameters.GUI.OdorA_bank)];
        secbank = ['Bank' num2str(TaskParameters.GUI.OdorB_bank)];
        
        if softCode < 9
            if ~BpodSystem.EmulatorMode
                CommandValve = Valves2EthernetString(firstbank, softCode, secbank, softCode); % softCode := desired valve number
                TCPWrite(BpodSystem.Data.Custom.OlfIp, 3336, CommandValve);
            end
        elseif softCode == 9
            nextTrial = numel(BpodSystem.Data.Custom.TrialNumber) + 2;
            OdorA_flow = BpodSystem.Data.Custom.OdorFracA(nextTrial);
            OdorB_flow = 100 - OdorA_flow;
            if ~BpodSystem.EmulatorMode
                SetBankFlowRate(BpodSystem.Data.Custom.OlfIp, TaskParameters.GUI.OdorA_bank, OdorA_flow)
                SetBankFlowRate(BpodSystem.Data.Custom.OlfIp, TaskParameters.GUI.OdorB_bank, OdorB_flow)
            end
        end
        
    end %if olfactometer initialized
end %if olfactory soft codes

if softCode > 10 && softCode < 21 %for auditory clicks
    if ~BpodSystem.EmulatorMode
if softCode == 11 %noise on chan 1
            tic
            SendBpodSoftCode(5)
            toc
            ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamFeedback);
            toc
            SendBpodSoftCode(6)
            toc
            SendCustomPulseTrain(1,cumsum(randi(9,1,601))/10000,(rand(1,601)-.5)*20); % White(?) noise on channel 1+2
            SendCustomPulseTrain(2,cumsum(randi(9,1,601))/10000,(rand(1,601)-.5)*20);
            TriggerPulsePal(1,2);
            toc
%            ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamStimulus);
        elseif softCode == 12 %beep on chan 2
            ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamFeedback);
           % toc
            SendCustomPulseTrain(2,0:.001:.3,(ones(1,301)*3));  % Beep on channel 1+2
           % toc
            SendCustomPulseTrain(1,0:.001:.3,(ones(1,301)*3));
           % toc
            TriggerPulsePal(1,2);
            
        
        elseif softCode == 15 %beep on chan 2
            ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamFeedback);
           % toc
            SendCustomPulseTrain(2,0:.0004:.3,(ones(1,751)*3));  % Beep on channel 1+2
           % toc
            SendCustomPulseTrain(1,0:.0004:.3,(ones(1,751)*3));
           % toc
            TriggerPulsePal(1,2);
         
        elseif softCode == 14 %beep on chan 2
            ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamFeedback);
           % toc
            SendCustomPulseTrain(2,0:.0006:.3,(ones(1,501)*3));  % Beep on channel 1+2
           % toc
            SendCustomPulseTrain(1,0:.0006:.3,(ones(1,501)*3));
           % toc
            TriggerPulsePal(1,2);         
        elseif softCode == 13 %beep on chan 2
            ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamFeedback);
           % toc
            SendCustomPulseTrain(2,0:.0009:.3,(ones(1,334)*3));  % Beep on channel 1+2
           % toc
            SendCustomPulseTrain(1,0:.0009:.3,(ones(1,334)*3));
           % toc
            TriggerPulsePal(1,2);  
        end
    end
end

if softCode > 20 && softCode < 31 %for auditory freq
    if softCode == 21 
        if BpodSystem.Data.Custom.PsychtoolboxStartup
            PsychToolboxSoundServer('Play', 1);
        end
    end
    if softCode == 22
        if BpodSystem.Data.Custom.PsychtoolboxStartup
            PsychToolboxSoundServer('Stop', 1);
        end
    end    
end

%laser stimulation protocols
if softCode > 30 && softCode < 41 %for laser stuff
    if softCode==31
        if  BpodSystem.Data.Custom.LaserTrial(end) && TaskParameters.GUI.LaserSoftCode %laser trial and laser via softcode setting
            if TaskParameters.GUI.LaserTimeInvestment
                %this soft code 'solution' only works for time investment
                %inhibition with a significant delay to allow for loading
                %the soft code. stupid hack bc PulsePal only supports 2
                %custom pulse trains and you can only have 1 pulsepal.
                %soft code is called at beginning of time investment to
                %load pulsepal matrix for laser stimulation
                Params=struct();
                Params.Length=TaskParameters.GUI.LaserTrainDuration_ms/1000; %in sec. train INCLUDES RAMP
                Params.Ramp = TaskParameters.GUI.LaserRampDuration_ms/1000;
                Params.Amp = TaskParameters.GUI.LaserAmp;
                Params.TriggerOutChan=3;
                Params.LaserOutChan=4;
                Params.TriggerInChan=2;
                Params.CustomPulseTrainID=1;
                Params.DelayStart=BpodSystem.Data.Custom.LaserTrialTrainStart(end);
                P=configurePulsePalLaser_CustomTrain(Params);
            end
        end
         SendBpodSoftCode(1); %send back to Bpod that we're done here, only then state matrix continues
    end
end

% switch odorID
%     case 0
%         CommandValveMinOil = Valves2EthernetString(firstbank, 2, secbank, 2);
%         TCPWrite(BpodSystem.Data.Custom.OlfIp, 3336, CommandValveMinOil);
%     case 1
%         CommandValveScent = Valves2EthernetString(firstbank, 1, secbank, 1); % From RechiaOlfactometer plugin. Simultaneously sets banks 1 and 2 to valve 1
%         TCPWrite(BpodSystem.Data.Custom.OlfIp, 3336, CommandValveScent);
end

