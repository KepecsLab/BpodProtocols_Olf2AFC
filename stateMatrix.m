function sma = stateMatrix(iTrial)
global BpodSystem
global TaskParameters

%% Define ports
LeftPort = floor(mod(TaskParameters.GUI.Ports_LMR/100,10));
CenterPort = floor(mod(TaskParameters.GUI.Ports_LMR/10,10));
RightPort = mod(TaskParameters.GUI.Ports_LMR,10);
LeftPortOut = strcat('Port',num2str(LeftPort),'Out');
CenterPortOut = strcat('Port',num2str(CenterPort),'Out');
RightPortOut = strcat('Port',num2str(RightPort),'Out');
LeftPortIn = strcat('Port',num2str(LeftPort),'In');
CenterPortIn = strcat('Port',num2str(CenterPort),'In');
RightPortIn = strcat('Port',num2str(RightPort),'In');


BCenterPort = TaskParameters.GUI.bPort;
BCenterPortIn = strcat('Port',num2str(BCenterPort),'In');
BCenterPortOut = strcat('Port',num2str(BCenterPort),'Out');

small_amount = TaskParameters.GUI.S_ra;
medium_amount = TaskParameters.GUI.M_ra;
large_amount = TaskParameters.GUI.L_ra;

SmallValveTime  = GetValveTimes(small_amount, BCenterPort);
MediumValveTime  = GetValveTimes(medium_amount, BCenterPort);
LargeValveTime  = GetValveTimes(large_amount, BCenterPort);

LeftValve = 2^(LeftPort-1);
RightValve = 2^(RightPort-1);
BCenterValve=2^(BCenterPort-1);

%port LEDs
if TaskParameters.GUI.PortLEDs
    PortLEDs = 255;
else
    PortLEDs = 0;
end

if BpodSystem.Data.Custom.AuditoryTrial(iTrial) %auditory trial
    LeftRewarded = BpodSystem.Data.Custom.LeftRewarded(iTrial);
else %olfactory trial
    LeftRewarded = BpodSystem.Data.Custom.OdorID(iTrial) == 1;
end

if LeftRewarded == 1
    LeftPokeAction1 = 'Rewarded_Bin_Wait1';
    RightPokeAction1 = 'unRewarded_Bin_Wait1';
    LeftPokeAction2 = 'Rewarded_Bin_Wait2';
    RightPokeAction2 = 'unRewarded_Bin_Wait2';
    LeftPokeAction3 = 'Rewarded_Bin_Wait3';
    RightPokeAction3 = 'unRewarded_Bin_Wait3';
elseif LeftRewarded == 0
    LeftPokeAction1 = 'unRewarded_Bin_Wait1';
    RightPokeAction1 = 'Rewarded_Bin_Wait1';
    LeftPokeAction2 = 'unRewarded_Bin_Wait2';
    RightPokeAction2 = 'Rewarded_Bin_Wait2';
    LeftPokeAction3 = 'unRewarded_Bin_Wait3';
    RightPokeAction3 = 'Rewarded_Bin_Wait3';
else
    error('Bpod:Olf2AFC:unknownStim','Undefined stimulus');
end


% if BpodSystem.Data.Custom.CatchTrial(iTrial)
%     FeedbackDelayCorrect = 20;
% else
%     FeedbackDelayCorrect = TaskParameters.GUI.FeedbackDelay;
% end
% if TaskParameters.GUI.CatchError
%     FeedbackDelayError = 20;
% else
%     FeedbackDelayError = TaskParameters.GUI.FeedbackDelay;
% end

%Wire1 settings
%no video default
Wire1OutError = {};
Wire1OutCorrect =	{};
Wire1Out = {};
if TaskParameters.GUI.Wire1VideoTrigger % video
    switch TaskParameters.GUI.VideoTrials
        case 1 %only catch & error
            Wire1OutError =	{'WireState', 1};
            if BpodSystem.Data.Custom.CatchTrial(iTrial)
                Wire1OutCorrect =	{'WireState', 1};
            else
                Wire1OutCorrect =	{};
            end
        case 2 %all trials
            Wire1Out =	{'WireState', 1};
    end
end

%BNC2 settings -- assumes connection from Bpod BNC2 out to Trigger 2 of
%PulsePal to trigger PulsePal's output channel 3+4 connected to laser & recording
%system to switch laser on
%default: no laser, no BNC to high.
BNC2OutWT = 0;
BNC2OutST = 0;
BNC2OutPre = 0;
BNC2OutMT = 0;
BNC2OutReward = 0;
BNC2OutFB = 0;
BNC2OutITI = 0;
BNC2OutWaitC=0;
if  BpodSystem.Data.Custom.LaserTrial(iTrial) %laser trial. BNC2 to high (1 still low).
    if TaskParameters.GUI.LaserTimeInvestment
    BNC2OutWT = 2;%waiting time states
    end
    if TaskParameters.GUI.LaserStim
    BNC2OutST = 2;%stimulus time states
    end
    if TaskParameters.GUI.LaserPreStim
    BNC2OutPre = 2;%pre stimulus states
    end
    if TaskParameters.GUI.LaserMov
    BNC2OutMT = 2;%movement states
    end
    if TaskParameters.GUI.LaserRew
    BNC2OutReward = 2;%reward delivery
    end
    if TaskParameters.GUI.LaserFeedback
    BNC2OutFB = 2;%feedback states (delays)
    end
    if TaskParameters.GUI.LaserITI
    BNC2OutITI = 2; %iti (iti at end of trial)
    end
end

if  BpodSystem.Data.Custom.LaserTrial(max([1,iTrial-1]))%last trial was laser trial
    if TaskParameters.GUI.LaserITI
        BNC2OutWaitC = 2; %'iti' (pre center poke enter)
    end
end
    

%% Build state matrix
sma = NewStateMatrix();
sma = SetGlobalTimer(sma,1,TaskParameters.GUI.FeedbackDelay1);
sma = SetGlobalTimer(sma,2,TaskParameters.GUI.FeedbackDelay2);
sma = SetGlobalTimer(sma,3,TaskParameters.GUI.FeedbackDelay3);


sma = AddState(sma, 'Name', 'PreITI_start',...
    'Timer', 0.05,...
    'StateChangeConditions', {'Tup','preITI'},...
    'OutputActions', Wire1Out);
sma = AddState(sma, 'Name', 'preITI',...
    'Timer', TaskParameters.GUI.PreITI,...
    'StateChangeConditions', {'Tup','wait_Cin'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'wait_Cin',...
    'Timer', TaskParameters.GUI.CenterWaitMax,...
    'StateChangeConditions', {CenterPortIn, 'stay_Cin','Tup','ITI'},...
    'OutputActions', {'SoftCode',1,strcat('PWM',num2str(CenterPort)),PortLEDs,'BNCState',BNC2OutWaitC});
sma = AddState(sma, 'Name', 'broke_fixation',...
    'Timer',0,...
    'StateChangeConditions',{'Tup','timeOut_BrokeFixation'},...
    'OutputActions',{});
% sma = AddState(sma, 'Name', 'pre_odor_delivery',...
%     'Timer', 0.1,... % Time for odor to reach nostrils (Junya filtered these trials out offline)
%     'StateChangeConditions', {CenterPortOut,'ITI','Tup','odor_delivery'},...
%     'OutputActions', {'SoftCode',BpodSystem.Data.Custom.OdorPair(iTrial)});
if BpodSystem.Data.Custom.AuditoryTrial(iTrial)
    if BpodSystem.Data.Custom.ClickTask(iTrial)
        sma = AddState(sma, 'Name', 'stay_Cin',...
            'Timer', TaskParameters.GUI.StimDelay,...
            'StateChangeConditions', {CenterPortOut,'broke_fixation','Tup', 'stimulus_delivery_min'},...
            'OutputActions',{'BNCState',BNC2OutPre});
        sma = AddState(sma, 'Name', 'stimulus_delivery_min',...
            'Timer', TaskParameters.GUI.MinSampleAud,...
            'StateChangeConditions', {CenterPortOut,'early_withdrawal','Tup','stimulus_delivery'},...
            'OutputActions', {'BNCState',1+BNC2OutST});
        sma = AddState(sma, 'Name', 'early_withdrawal',...
            'Timer',0,...
            'StateChangeConditions',{'Tup','timeOut_EarlyWithdrawal'},...
            'OutputActions',{'BNCState',0});
        sma = AddState(sma, 'Name', 'stimulus_delivery',...
            'Timer', TaskParameters.GUI.AuditoryStimulusTime - TaskParameters.GUI.MinSampleAud,...
            'StateChangeConditions', {CenterPortOut,'wait_Sin_start','Tup','wait_Sin_start'},...
            'OutputActions', {'BNCState',1+BNC2OutST});
        if TaskParameters.GUI.LaserSoftCode
            sma=AddState(sma,'Name','wait_Sin_start',...
                'Timer',.3,...
                'StateChangeConditions', {'Tup','ITI','SoftCode2','wait_Sin'},...%listen back for softcode
                'OutputActions',{'SoftCode',31});
        else
            sma=AddState(sma,'Name','wait_Sin_start',...
                'Timer',0,...
                'StateChangeConditions', {'Tup','wait_Sin'},...%move on directly
                'OutputActions',{});            
        end
        sma = AddState(sma, 'Name', 'wait_Sin',...
            'Timer',TaskParameters.GUI.ChoiceDeadLine,...
            'StateChangeConditions', {LeftPortIn,'start_Lin',RightPortIn,'start_Rin','Tup','missed_choice'},...
            'OutputActions',{'BNCState',0+BNC2OutMT,strcat('PWM',num2str(LeftPort)),PortLEDs,strcat('PWM',num2str(RightPort)),PortLEDs});
    else %frequency task 
        sma = AddState(sma, 'Name', 'stay_Cin',...
            'Timer', TaskParameters.GUI.StimDelay,...
            'StateChangeConditions', {CenterPortOut,'broke_fixation','Tup', 'stimulus_delivery_trigger'},...
            'OutputActions',{'BNCState',BNC2OutPre});
        sma = AddState(sma, 'Name', 'stimulus_delivery_trigger',...
            'Timer', 0.1,...
            'StateChangeConditions', {CenterPortOut,'broke_fixation','Tup','No_Stim','BNC1High','stimulus_delivery_min'},...
            'OutputActions', {'SoftCode',21,'BNCState',BNC2OutST});%play stim
        sma = AddState(sma, 'Name', 'No_Stim',...
            'Timer', 0.01,...
            'StateChangeConditions', {'Tup','ITI'},...
            'OutputActions', {'SoftCode',22});%stop stim     
        sma = AddState(sma, 'Name', 'stimulus_delivery_min',...
            'Timer', TaskParameters.GUI.MinSampleAud,...
            'StateChangeConditions', {CenterPortOut,'early_withdrawal','Tup','stimulus_delivery'},...
            'OutputActions', {'BNCState',BNC2OutST});
        sma = AddState(sma, 'Name', 'early_withdrawal',...
            'Timer',0,...
            'StateChangeConditions',{'Tup','timeOut_EarlyWithdrawal'},...
            'OutputActions',{'SoftCode',22});%stop stim   
        sma = AddState(sma, 'Name', 'stimulus_delivery',...
            'Timer', TaskParameters.GUI.AuditoryStimulusTime - TaskParameters.GUI.MinSampleAud,...
            'StateChangeConditions', {CenterPortOut,'wait_Sin','Tup','wait_Sin'},...
            'OutputActions', {'BNCState',BNC2OutST});
        sma = AddState(sma, 'Name', 'wait_Sin',...
            'Timer',TaskParameters.GUI.ChoiceDeadLine,...
            'StateChangeConditions', {LeftPortIn,'start_Lin',RightPortIn,'start_Rin','Tup','missed_choice'},...
            'OutputActions',{'BNCState',BNC2OutMT,'SoftCode',22,strcat('PWM',num2str(LeftPort)),PortLEDs,strcat('PWM',num2str(RightPort)),PortLEDs});
    end
else
    sma = AddState(sma, 'Name', 'stay_Cin',...
        'Timer', TaskParameters.GUI.StimDelay,...
        'StateChangeConditions', {CenterPortOut,'broke_fixation','Tup', 'stimulus_delivery_min'},...
        'OutputActions',{'BNCState',BNC2OutPre});
    sma = AddState(sma, 'Name', 'stimulus_delivery_min',...
        'Timer', TaskParameters.GUI.OdorStimulusTimeMin,...
        'StateChangeConditions', {CenterPortOut,'early_withdrawal','Tup','stimulus_delivery'},...
        'OutputActions', {'BNCState',BNC2OutST,'SoftCode',BpodSystem.Data.Custom.OdorPair(iTrial)});
    sma = AddState(sma, 'Name', 'early_withdrawal',...
        'Timer',0,...
        'StateChangeConditions',{'Tup','timeOut_EarlyWithdrawal'},...
        'OutputActions',{});
    sma = AddState(sma, 'Name', 'stimulus_delivery',...
        'Timer', 0,...
        'StateChangeConditions', {CenterPortOut,'wait_Sin'},...
        'OutputActions', {'BNCState',BNC2OutST});
    sma = AddState(sma, 'Name', 'wait_Sin',...
        'Timer',TaskParameters.GUI.ChoiceDeadLine,...
        'StateChangeConditions', {LeftPortIn,'start_Lin',RightPortIn,'start_Rin','Tup','missed_choice'},...
        'OutputActions',{'BNCState',BNC2OutMT,'SoftCode',1,strcat('PWM',num2str(LeftPort)),PortLEDs,strcat('PWM',num2str(RightPort)),PortLEDs});
end
sma = AddState(sma, 'Name','start_Lin',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','Lin'},...
    'OutputActions',{'GlobalTimerTrig',1});

sma = AddState(sma, 'Name','start_Rin',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','Rin'},...
    'OutputActions',{'GlobalTimerTrig',1});

sma = AddState(sma, 'Name', 'Lin',...
    'Timer', TaskParameters.GUI.FeedbackDelay1,...
    'StateChangeConditions', {LeftPortOut,'Lin_grace','Tup','left_acheived_2','GlobalTimer1_End','left_acheived_2'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'Rin',...
    'Timer', TaskParameters.GUI.FeedbackDelay1,...
    'StateChangeConditions', {RightPortOut,'Rin_grace','Tup','right_acheived_2','GlobalTimer1_End','right_acheived_2'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'Lin_grace',...
    'Timer', TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions',{'Tup','skipped_feedback',LeftPortIn,'start_Lin'},...
    'OutputActions', {strcat('PWM',num2str(LeftPort)),50});

sma = AddState(sma, 'Name', 'Rin_grace',...
    'Timer', TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions',{'Tup','skipped_feedback',RightPortIn,'start_Rin'},...
    'OutputActions', {strcat('PWM',num2str(RightPort)),50});

sma = AddState(sma, 'Name','left_acheived_2',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','start_Lin2'},...
    'OutputActions',{});

sma = AddState(sma, 'Name','right_acheived_2',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','start_Rin2'},...
    'OutputActions',{});

sma = AddState(sma, 'Name','start_Lin2',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','Lin2'},...
    'OutputActions',{'GlobalTimerTrig',2});

sma = AddState(sma, 'Name','start_Rin2',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','Rin2'},...
    'OutputActions',{'GlobalTimerTrig',2});

sma = AddState(sma, 'Name', 'Lin2',...
    'Timer', TaskParameters.GUI.FeedbackDelay2,...
    'StateChangeConditions', {LeftPortOut,'Lin2_grace','Tup','left_achieved_3','GlobalTimer4_End','left_achieved_3'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'Rin2',...
    'Timer', TaskParameters.GUI.FeedbackDelay2,...
    'StateChangeConditions', {RightPortOut,'Rin2_grace','Tup','right_achieved_3','GlobalTimer4_End','right_achieved_3'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'Lin2_grace',...
    'Timer', TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions',{'Tup',LeftPokeAction1,LeftPortIn,'Lin2'},...
    'OutputActions', {strcat('PWM',num2str(LeftPort)),50});

sma = AddState(sma, 'Name', 'Rin2_grace',...
    'Timer', TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions',{'Tup',RightPokeAction1,RightPortIn,'Rin2'},...
    'OutputActions', {strcat('PWM',num2str(RightPort)),50});

sma = AddState(sma, 'Name','left_achieved_3',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','start_Lin3'},...
    'OutputActions',{});

sma = AddState(sma, 'Name','right_achieved_3',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','start_Rin3'},...
    'OutputActions',{});

sma = AddState(sma, 'Name','start_Lin3',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','Lin3'},...
    'OutputActions',{'GlobalTimerTrig',3});

sma = AddState(sma, 'Name','start_Rin3',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','Rin3'},...
    'OutputActions',{'GlobalTimerTrig',3});

sma = AddState(sma, 'Name', 'Lin3',...
    'Timer', TaskParameters.GUI.FeedbackDelay3,...
    'StateChangeConditions', {LeftPortOut,'Lin3_grace','Tup',LeftPokeAction3,'GlobalTimer5_End',LeftPokeAction3},...
    'OutputActions', {});
 
sma = AddState(sma, 'Name', 'Rin3',...
    'Timer', TaskParameters.GUI.FeedbackDelay3,...
    'StateChangeConditions', {RightPortOut,'Rin3_grace','Tup',RightPokeAction3,'GlobalTimer5_End',RightPokeAction3},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'Lin3_grace',...
    'Timer', TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions',{'Tup',LeftPokeAction2,LeftPortIn,'Lin3',},...
    'OutputActions', { strcat('PWM',num2str(BCenterPort)),50});

sma = AddState(sma, 'Name', 'Rin3_grace',...
    'Timer', TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions',{'Tup',RightPokeAction2,RightPortIn,'Rin3'},...
    'OutputActions', {strcat('PWM',num2str(BCenterPort)),50});

sma = AddState(sma, 'Name', 'Rewarded_Bin_Wait1',...
    'Timer', TaskParameters.GUI.ChoiceDeadLine,...
    'StateChangeConditions', {'Tup','ITI', BCenterPortIn,  'water_S'},...
    'OutputActions', {'SoftCode', 13,strcat('PWM',num2str(BCenterPort)),PortLEDs});
sma = AddState(sma, 'Name', 'Rewarded_Bin_Wait2',...
    'Timer', TaskParameters.GUI.ChoiceDeadLine,...
    'StateChangeConditions', {'Tup','ITI', BCenterPortIn, 'water_M'},...
    'OutputActions', {'SoftCode', 14,strcat('PWM',num2str(BCenterPort)),PortLEDs});

sma = AddState(sma, 'Name', 'Rewarded_Bin_Wait3',...
    'Timer', TaskParameters.GUI.ChoiceDeadLine,...
    'StateChangeConditions', {'Tup','ITI', BCenterPortIn, 'water_L'},...
    'OutputActions', {'SoftCode', 15, strcat('PWM',num2str(BCenterPort)),PortLEDs});

sma = AddState(sma, 'Name', 'water_S',...
    'Timer', SmallValveTime,...
    'StateChangeConditions', {'Tup','Drinking'},...
    'OutputActions', {'ValveState', BCenterValve, 'SoftCode', 13});
sma = AddState(sma, 'Name', 'water_M',...
    'Timer', MediumValveTime,...
    'StateChangeConditions', {'Tup','Drinking'},...
    'OutputActions', {'ValveState', BCenterValve, 'SoftCode', 14});
sma = AddState(sma, 'Name', 'water_L',...
    'Timer', LargeValveTime,...
    'StateChangeConditions', {'Tup','Drinking'},...
    'OutputActions', {'ValveState', BCenterValve, 'SoftCode', 15});

sma = AddState(sma, 'Name', 'unRewarded_Bin_Wait1',...
    'Timer', TaskParameters.GUI.ChoiceDeadLine,...
    'StateChangeConditions', {'Tup','ITI', BCenterPortIn,  'unRewarded_Bin_S'},...
    'OutputActions', {'SoftCode', 13,strcat('PWM',num2str(BCenterPort)),PortLEDs});

sma = AddState(sma, 'Name', 'unRewarded_Bin_Wait2',...
    'Timer', TaskParameters.GUI.ChoiceDeadLine,...
    'StateChangeConditions', {'Tup','ITI',BCenterPortIn, 'unRewarded_Bin_M'},...
    'OutputActions', {'SoftCode', 14, strcat('PWM',num2str(BCenterPort)),PortLEDs});

sma = AddState(sma, 'Name', 'unRewarded_Bin_Wait3',...
    'Timer', TaskParameters.GUI.ChoiceDeadLine,...
    'StateChangeConditions', {'Tup','ITI', BCenterPortIn, 'unRewarded_Bin_L'},...
    'OutputActions', {'SoftCode', 15, strcat('PWM',num2str(BCenterPort)),PortLEDs});

sma = AddState(sma, 'Name', 'unRewarded_Bin_S',...
    'Timer', 0.05,...
    'StateChangeConditions', {'Tup','timeOut_IncorrectChoice'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'unRewarded_Bin_M',...
    'Timer', 0.05,...
    'StateChangeConditions', {'Tup','timeOut_IncorrectChoice'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'unRewarded_Bin_L',...
    'Timer', 0.05,...
    'StateChangeConditions', {'Tup','timeOut_IncorrectChoice'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'Drinking',...
    'Timer', TaskParameters.GUI.DrinkingTime,...
    'StateChangeConditions', {'Tup','ITI', BCenterPortOut,  'DrinkingGrace'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'DrinkingGrace',...
    'Timer', TaskParameters.GUI.DrinkingGrace,...
    'StateChangeConditions', {'Tup','ITI', BCenterPortIn, 'Drinking'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'timeOut_BrokeFixation',...
    'Timer',TaskParameters.GUI.TimeOutBrokeFixation,...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',{'SoftCode',11,'BNCState',BNC2OutFB});
sma = AddState(sma, 'Name', 'timeOut_EarlyWithdrawal',...
    'Timer',TaskParameters.GUI.TimeOutEarlyWithdrawal,...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',{'SoftCode',11,'BNCState',BNC2OutFB});
if  TaskParameters.GUI.IncorrectChoiceFeedbackType == 2 % IncorrectChoiceFeedbackType == Tone
    sma = AddState(sma, 'Name', 'timeOut_IncorrectChoice',...
        'Timer',TaskParameters.GUI.TimeOutIncorrectChoice,...
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'SoftCode',11,'BNCState',BNC2OutFB});
elseif  TaskParameters.GUI.IncorrectChoiceFeedbackType == 3 % IncorrectChoiceFeedbackType == PortLED
    sma = AddState(sma, 'Name', 'timeOut_IncorrectChoice',...
        'Timer',0.1,...
        'StateChangeConditions',{'Tup','timeOut_IncorrectChoice2'},...
        'OutputActions',{strcat('PWM',num2str(LeftPort)),PortLEDs,strcat('PWM',num2str(CenterPort)),PortLEDs,strcat('PWM',num2str(RightPort)),PortLEDs,'BNCState',BNC2OutFB});
    sma = AddState(sma, 'Name', 'timeOut_IncorrectChoice2',...
        'Timer',TaskParameters.GUI.TimeOutIncorrectChoice,... 
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'BNCState',BNC2OutFB});
else % IncorrectChoiceFeedbackType == None
    sma = AddState(sma, 'Name', 'timeOut_IncorrectChoice',...
        'Timer',TaskParameters.GUI.TimeOutIncorrectChoice,...
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'BNCState',BNC2OutFB});
end
if  TaskParameters.GUI.SkippedFeedbackFeedbackType == 2 % SkippedFeedbackFeedbackType == Tone
    sma = AddState(sma, 'Name', 'timeOut_SkippedFeedback',...
        'Timer',TaskParameters.GUI.TimeOutSkippedFeedback,...
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'SoftCode',12,'BNCState',BNC2OutFB});
elseif  TaskParameters.GUI.SkippedFeedbackFeedbackType == 3 % SkippedFeedbackFeedbackType == PortLED
    sma = AddState(sma, 'Name', 'timeOut_SkippedFeedback',...
        'Timer',0.1,...
        'StateChangeConditions',{'Tup','timeOut_SkippedFeedback2'},...
        'OutputActions',{strcat('PWM',num2str(LeftPort)),PortLEDs,strcat('PWM',num2str(CenterPort)),PortLEDs,strcat('PWM',num2str(RightPort)),PortLEDs,'BNCState',BNC2OutFB});
    sma = AddState(sma, 'Name', 'timeOut_SkippedFeedback2',...
        'Timer',TaskParameters.GUI.TimeOutSkippedFeedback,... 
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'BNCState',BNC2OutFB});
else % SkippedFeedbackFeedbackType == None
    sma = AddState(sma, 'Name', 'timeOut_SkippedFeedback',...
        'Timer',TaskParameters.GUI.TimeOutSkippedFeedback,...
        'StateChangeConditions',{'Tup','ITI'},...
        'OutputActions',{'BNCState',BNC2OutFB});
end
sma = AddState(sma, 'Name', 'skipped_feedback',...
    'Timer', 0,...
    'StateChangeConditions', {'Tup','timeOut_SkippedFeedback'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'missed_choice',...
    'Timer',0,...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'ITI',...
    'Timer',max(TaskParameters.GUI.ITI,0.5),...
    'StateChangeConditions',{'Tup','exit'},...
    'OutputActions',{'SoftCode',9,'BNCState',BNC2OutITI}); % Sets flow rates for next trial
% sma = AddState(sma, 'Name', 'state_name',...
%     'Timer', 0,...
%     'StateChangeConditions', {},...
%     'OutputActions', {});
end
