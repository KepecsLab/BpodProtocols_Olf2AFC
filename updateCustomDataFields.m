function updateCustomDataFields
global BpodSystem
global TaskParameters
%% OutcomeRecord
% Searches for state names and not number, so won't be affected by
% modifications in state matrix
ndxOutcome = find(strcmp('rewarded_Lin',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}) |...
    strcmp('rewarded_Rin',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}) |...
    strcmp('unrewarded_Lin',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}) |...
    strcmp('unrewarded_Rin',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}) |...
    strcmp('broke_fixation',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end})); % States of interest
if any(ismember(ndxOutcome,BpodSystem.Data.RawData.OriginalStateData{end}))
    BpodSystem.Data.Custom.OutcomeRecord(end) = ndxOutcome(ismember(ndxOutcome,BpodSystem.Data.RawData.OriginalStateData{end}));
    if strcmp('rewarded_Lin',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}(BpodSystem.Data.Custom.OutcomeRecord(end)))
        BpodSystem.Data.Custom.ChoiceLeft(end) = 1;
        BpodSystem.Data.Custom.Rewarded(end) = 1;
    elseif strcmp('rewarded_Rin',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}(BpodSystem.Data.Custom.OutcomeRecord(end)))
        BpodSystem.Data.Custom.ChoiceLeft(end) = 0;
        BpodSystem.Data.Custom.Rewarded(end) = 1;
    elseif strcmp('unrewarded_Lin',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}(BpodSystem.Data.Custom.OutcomeRecord(end)))
        BpodSystem.Data.Custom.ChoiceLeft(end) = 1;
        BpodSystem.Data.Custom.Rewarded(end) = 0;
    elseif strcmp('unrewarded_Rin',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}(BpodSystem.Data.Custom.OutcomeRecord(end)))
        BpodSystem.Data.Custom.ChoiceLeft(end) = 0;
        BpodSystem.Data.Custom.Rewarded(end) = 0;
    elseif strcmp('broke_fixation',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}(BpodSystem.Data.Custom.OutcomeRecord(end)))
        BpodSystem.Data.Custom.FixBroke(end) = true;
        BpodSystem.Data.Custom.TrialValid(end) = false;
    end
    if any(strcmp('skipped_feedback',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}(BpodSystem.Data.RawData.OriginalStateData{end})))
        BpodSystem.Data.Custom.TrialValid(end) = false;
        BpodSystem.Data.Custom.Feedback(end) = false;        
    end
end
if any(strcmp('odor_delivery',BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}(BpodSystem.Data.RawData.OriginalStateData{end})))
    BpodSystem.Data.Custom.OST(end) = diff(BpodSystem.Data.RawEvents.Trial{end}.States.odor_delivery);
end
if ~BpodSystem.Data.Custom.FixBroke(end)
    BpodSystem.Data.Custom.FeedbackTime(end) = diff(BpodSystem.Data.RawEvents.Trial{end}.States.(BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}{BpodSystem.Data.Custom.OutcomeRecord(end)}));
end

BpodSystem.Data.Custom.GotFeedback = 1;
BpodSystem.Data.Custom.OutcomeRecord(end+1) = nan;
BpodSystem.Data.Custom.ChoiceLeft(end+1) = NaN;
BpodSystem.Data.Custom.Rewarded(end+1) = NaN;
BpodSystem.Data.Custom.FixBroke(end+1) = false;
BpodSystem.Data.Custom.FixDur(end) = diff(BpodSystem.Data.RawEvents.Trial{end}.States.stay_Cin);
BpodSystem.Data.Custom.FixDur(end+1) = NaN;
BpodSystem.Data.Custom.OST(end+1) = NaN;
BpodSystem.Data.Custom.TrialValid(end+1) = true;
BpodSystem.Data.Custom.Feedback(end+1) = true;
BpodSystem.Data.Custom.FeedbackTime(end+1) = NaN;

if numel(BpodSystem.Data.Custom.OutcomeRecord) > numel(BpodSystem.Data.Custom.OdorFracA) - 10
    switch TaskParameters.GUIMeta.TrialSelection.String{TaskParameters.GUI.TrialSelection}
        case 'Flat'
            TaskParameters.GUI.OdorTable.OdorProb = ones(size(TaskParameters.GUI.OdorTable.OdorProb));
        case 'Manual'
            
        case 'Competitive'
            ndxValid = [or(BpodSystem.Data.Custom.TrialValid(1:end-1),BpodSystem.Data.Custom.Feedback(1:end-1)==0)...
                false(1,1+numel(BpodSystem.Data.Custom.OdorFracA)-numel(BpodSystem.Data.Custom.TrialValid))];
            if numel(BpodSystem.Data.Custom.OdorFracA(ndxValid))/numel(unique(BpodSystem.Data.Custom.OdorFracA)) >= 8
                for iStim = TaskParameters.GUI.OdorTable.OdorFracA'
                    ndxOdor = BpodSystem.Data.Custom.OdorFracA(1:numel(BpodSystem.Data.Custom.Rewarded)) == iStim;
                    if any(ndxOdor)
                        TaskParameters.GUI.OdorTable.OdorProb(iStim == TaskParameters.GUI.OdorTable.OdorFracA) = ...
                            1 - sum(BpodSystem.Data.Custom.Rewarded(ndxOdor)==1)/sum(ndxOdor);
                    end
                end
            end
        case 'BiasCorrecting' % Favors side with fewer rewards. Contrast drawn flat & independently.
            ndxCorrect = BpodSystem.Data.Custom.Rewarded(1:end-1) == 1; ndxCorrect = ndxCorrect(:);
            oldOdorID = BpodSystem.Data.Custom.OdorID(1:numel(ndxCorrect)); oldOdorID = oldOdorID(:);
            TaskParameters.GUI.OdorTable.OdorProb(TaskParameters.GUI.OdorTable.OdorFracA<50) = 1-sum(oldOdorID==2 & ndxCorrect)/sum(ndxCorrect);
            TaskParameters.GUI.OdorTable.OdorProb(TaskParameters.GUI.OdorTable.OdorFracA>50) = 1-sum(oldOdorID==1 & ndxCorrect)/sum(ndxCorrect);            
    end
    newFracA = randsample(TaskParameters.GUI.OdorTable.OdorFracA,20,1,TaskParameters.GUI.OdorTable.OdorProb);
    newOdorID =  2 - double(newFracA > 50);
    newOdorPair = ones(1,20);
    BpodSystem.Data.Custom.OdorFracA = [BpodSystem.Data.Custom.OdorFracA; newFracA];
    BpodSystem.Data.Custom.OdorID = [BpodSystem.Data.Custom.OdorID, newOdorID];
%     BpodSystem.Data.Custom.OdorContrast = [BpodSystem.Data.Custom.OdorContrast, newOdorContrast];
    BpodSystem.Data.Custom.OdorPair = [BpodSystem.Data.Custom.OdorPair, newOdorPair];
    clear newOdor* oldOdorID
end
TaskParameters.GUI.OdorTable.OdorProb = TaskParameters.GUI.OdorTable.OdorProb/sum(TaskParameters.GUI.OdorTable.OdorProb);
%% Olfactometer banks
BpodSystem.Data.Custom.OdorA_bank = TaskParameters.GUI.OdorA_bank;
BpodSystem.Data.Custom.OdorB_bank = TaskParameters.GUI.OdorB_bank;
%% Delays
if TaskParameters.GUI.StimDelayAutoincrement
    if BpodSystem.Data.Custom.FixBroke(end-1)
        BpodSystem.Data.Custom.StimDelay(end+1) = max(TaskParameters.GUI.StimDelayMin,...
            BpodSystem.Data.Custom.StimDelay(end)-TaskParameters.GUI.StimDelayDecr);
    else
        BpodSystem.Data.Custom.StimDelay(end+1) = min(TaskParameters.GUI.StimDelayMax,...
            BpodSystem.Data.Custom.StimDelay(end)+TaskParameters.GUI.StimDelayIncr);
    end
else
    if ~BpodSystem.Data.Custom.FixBroke(end-1)
        BpodSystem.Data.Custom.StimDelay(end+1) = random('unif',TaskParameters.GUI.StimDelayMin,TaskParameters.GUI.StimDelayMax);
    else
        BpodSystem.Data.Custom.StimDelay(end+1) = BpodSystem.Data.Custom.StimDelay(end);
    end
end
TaskParameters.GUI.StimDelay = BpodSystem.Data.Custom.StimDelay(end);

% if TaskParameters.GUI.FeedbackDelayAutoincrement
switch TaskParameters.GUIMeta.FeedbackDelaySelection.String{TaskParameters.GUI.FeedbackDelaySelection}
    case 'FixAuto'
        
        if ~BpodSystem.Data.Custom.Feedback(end-1)
            BpodSystem.Data.Custom.FeedbackDelay(end+1) = max(TaskParameters.GUI.FeedbackDelayMin,...
                BpodSystem.Data.Custom.FeedbackDelay(end)-TaskParameters.GUI.FeedbackDelayDecr);
        else
            BpodSystem.Data.Custom.FeedbackDelay(end+1) = min(TaskParameters.GUI.FeedbackDelayMax,...
                BpodSystem.Data.Custom.FeedbackDelay(end)+TaskParameters.GUI.FeedbackDelayIncr);
        end
        
        
    case 'TruncExp'
        
        BpodSystem.Data.Custom.FeedbackDelay(end+1) = TruncatedExponential(TaskParameters.GUI.FeedbackDelayMin,...
            TaskParameters.GUI.FeedbackDelayMax,TaskParameters.GUI.FeedbackDelayTau);
        
    case 'Fix'
        %     ATTEMPT TO GRAY OUT FIELDS
        %     if ~strcmp('edit',TaskParameters.GUIMeta.FeedbackDelay.Style)
        %         TaskParameters.GUIMeta.FeedbackDelay.Style = 'edit';
        %     end
        BpodSystem.Data.Custom.FeedbackDelay(end+1) = TaskParameters.GUI.FeedbackDelayMax;
        
end
TaskParameters.GUI.FeedbackDelay = BpodSystem.Data.Custom.FeedbackDelay(end);

%% Block count
% nTrialsThisBlock = sum(BpodSystem.Data.Custom.BlockNumber == BpodSystem.Data.Custom.BlockNumber(end));
% if nTrialsThisBlock >= TaskParameters.GUI.blockLenMax
%     % If current block len exceeds new max block size, will transition
%     BpodSystem.Data.Custom.BlockLen(end) = nTrialsThisBlock;
% end
% if nTrialsThisBlock >= BpodSystem.Data.Custom.BlockLen(end)
%     BpodSystem.Data.Custom.BlockNumber(end+1) = BpodSystem.Data.Custom.BlockNumber(end)+1;
%     BpodSystem.Data.Custom.BlockLen(end+1) = drawBlockLen(TaskParameters);
%     BpodSystem.Data.Custom.LeftHi(end+1) = ~BpodSystem.Data.Custom.LeftHi(end);
% else
%     BpodSystem.Data.Custom.BlockNumber(end+1) = BpodSystem.Data.Custom.BlockNumber(end);
%     BpodSystem.Data.Custom.LeftHi(end+1) = BpodSystem.Data.Custom.LeftHi(end);
% end
%display(BpodSystem.Data.RawData.OriginalStateNamesByNumber{end}(BpodSystem.Data.RawData.OriginalStateData{end}))

end

% function BlockLen = drawBlockLen(TaskParameters)
% BlockLen = 0;
% while BlockLen < TaskParameters.GUI.blockLenMin || BlockLen > TaskParameters.GUI.blockLenMax
%     BlockLen = ceil(exprnd(sqrt(TaskParameters.GUI.blockLenMin*TaskParameters.GUI.blockLenMax)));
% end
% end