local Base85Alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz}~!#$%&()*+,-./:;<>?@^_"
local function Decode85(EncodedString, OriginalLength)
    local AlphabetBuffer = buffer.fromstring(Base85Alphabet)
    local LookupTable = table.create(256, 0)
    for Index = 0, 84 do 
        LookupTable[buffer.readu8(AlphabetBuffer, Index)] = Index 
    end
    
    local Result = {}
    local Floor = math.floor
    local Byte = string.byte
    local Char = string.char
    for Index = 1, #EncodedString, 5 do
        local B1, B2, B3, B4, B5 = Byte(EncodedString, Index, Index + 4)
        local Value = LookupTable[B1] * 52200625 +
                      LookupTable[B2] * 614125 +
                      LookupTable[B3] * 7225 +
                      LookupTable[B4] * 85 +
                      LookupTable[B5]
                      
        Result[#Result + 1] = Char(
            Floor(Value / 16777216) % 256,
            Floor(Value / 65536) % 256,
            Floor(Value / 256) % 256,
            Value % 256
        )
    end
    
    local DecodedString = table.concat(Result)
    return OriginalLength and string.sub(DecodedString, 1, OriginalLength) or DecodedString
end

local function DecodeStrings(Encoded, TotalLen, Lengths, Count, StringKey)
    local Cache = {}
    local Decoded = nil
    local Offsets = nil
    local KeyByte = StringKey % 256
    local function GetString(Index)
        if Cache[Index] ~= nil then return Cache[Index] end
        if Decoded == nil then
            Decoded = Decode85(Encoded, TotalLen)
            Offsets = {}
            local Cursor = 1
            for I = 1, #Lengths do
                Offsets[I] = Cursor
                Cursor = Cursor + Lengths[I]
            end
        end
        local Start = Offsets[Index]
        local Len = Lengths[Index]
        local Raw = string.sub(Decoded, Start, Start + Len - 1)
        if KeyByte ~= 0 then
            local Parts = {}
            for Pos = 1, #Raw do
                local Byte = string.byte(Raw, Pos)
                Parts[Pos] = string.char(bit32.bxor(Byte, KeyByte))
            end
            Raw = table.concat(Parts)
        end
        Cache[Index] = Raw
        return Raw
    end
    local Proxy = {}
    setmetatable(Proxy, {
        __index = function(_, Key) return GetString(Key) end,
        __len = function() return Count end,
    })
    return Proxy
end

local function DeriveKey(KeySeed, KeyPosition)
    if KeySeed == 0 then return 0 end
    local DerivedKey = bit32.bxor(KeySeed, bit32.lshift(KeyPosition % 65536, 16))
    DerivedKey = bit32.bxor(DerivedKey, bit32.rshift(DerivedKey, 13))
    DerivedKey = bit32.bxor(DerivedKey, bit32.lshift(DerivedKey, 8))
    return DerivedKey % 4294967296
end

local function DecodeCode(Encoded, BuildKey, Count)
    local AlphabetBuffer = buffer.fromstring(Base85Alphabet)
    local Lookup = table.create(256, 0)
    for Index = 0, 84 do
        Lookup[buffer.readu8(AlphabetBuffer, Index)] = Index
    end
    local Cache = {}
    local function Get(InstructionIndex)
        if Cache[InstructionIndex] ~= nil then return Cache[InstructionIndex] end
        local Base = (InstructionIndex - 1) * 5 + 1
        local B1, B2, B3, B4, B5 = string.byte(Encoded, Base, Base + 4)
        local DecodedValue = Lookup[B1] * 52200625 + Lookup[B2] * 614125 + Lookup[B3] * 7225 + Lookup[B4] * 85 + Lookup[B5]
        DecodedValue = bit32.bxor(DecodedValue, DeriveKey(BuildKey, InstructionIndex))
        if DecodedValue > 2147483647 then DecodedValue = DecodedValue - 4294967296 end
        Cache[InstructionIndex] = DecodedValue
        return DecodedValue
    end
    local Proxy = {}
    setmetatable(Proxy, {
        __index = function(_, Key) return Get(Key) end,
        __len = function() return Count end,
    })
    return Proxy
end

local function DecodeNumbers(Encoded, Count)
    local Cache = {}
    local Parts = nil
    local function Get(InstructionIndex)
        if Cache[InstructionIndex] ~= nil then return Cache[InstructionIndex] end
        if Parts == nil then
            Parts = {}
            for Segment in string.gmatch(Encoded, "[^,]+") do
                Parts[#Parts + 1] = tonumber(Segment)
            end
        end
        local Value = Parts[InstructionIndex]
        Cache[InstructionIndex] = Value
        return Value
    end
    local Proxy = {}
    setmetatable(Proxy, {
        __index = function(_, Key) return Get(Key) end,
        __len = function() return Count end,
    })
    return Proxy
end

local DecryptionKey = 0
DecryptionKey = bit32.bxor(DecryptionKey, bit32.lshift(25, 8))
DecryptionKey = bit32.bxor(DecryptionKey, bit32.lshift(10, 0))
DecryptionKey = bit32.bxor(DecryptionKey, bit32.lshift(73, 24))
DecryptionKey = bit32.bxor(DecryptionKey, bit32.lshift(170, 16))
if type(DecryptionKey) ~= type(0) then DecryptionKey = 0 end

local CodeBlob0 = "jc07T,Nh8/+?O$y,:hdoh!#+D-lVWq-KD5a.GVz*i,&PM.*Js/.i1Ry/eK0o(7sqZ:A7;r/%-pd:!8P+#IkrB;X?I>;6}/w<2?np>C~qy<v(gt<UpFc>Q(*+oOsiw>?v!/>sdby?owAtf_Q4V@Kk3r?;Rzd}QBs9:.)6>}>_lB}rm8e~n_:,?:x%n!J+)@~:aVy!,,F9h^5B}#hz8D#GOse$Czc,<SRsX$%nV>$eC:w%an!A.dJt9&6bv6%!1I0&yc2-()J_?(UP>;(2-f~(_QPAyjjww)sEIE)Q}~?*NEm$qJ_6T*;2f>*op2yp^q>Sk_wjZqr4nUqP*LkrMfJ7p1mX8r/:,0rnxj.skTfS-%nPjtF$ASs,l(4t)H#7mbGJ:udsX^uCa6?v965Tim8Krv~gxPvaOWFwW<T8xgziLx2U^8wyCt_xu%pT)$a+wyQJKTx_0;Dy>t.4}sSO-zo7h^zM-G:fu9XpvKVlXgPk2ff^9mEg<@vUzMLZ6hnYQRhL@+HiI)<p!d+p$i,Mmpij*AvjgxIUwv-L.kCA+Pj(xXFk$lhqs&$MplZ_C&l8lwgm5Z%VnFH/gmx+aVmWZ@OnTO4q?2S1wn^ywqnuOJYorCSF+.1Q+pMm@Po>ChDVR~B}QvY@5V@p4yVtW!LWqc^nUVA0oXMQ/)W>8neX.dv}C_.5eYjRo$YI9PLZFFinR$}+YZ)3b&Zg)AkacGL~N;gaIb84F2a#)+vb}:8o6Ra7scW#1&c5kxrd0:%pO6Rvwdt#y?dSlWjePrsoMq^k2e>fl.erNKlL0Jo009fVJLt7h4LRu5$MO>a+ep&2mM<&UAMqV.#Nl?B0a~lpWOH(4CN.Wn^O+u@+E0x#CPgi/9PF8a:QAvx}V!SvuQ#jrNQc9D5RZXk,Zc3zGS5Le1R})0$SwYL17%gWyTSME5T0)x5T^A7,W,um0Uq^0_UPkk+Avy/J8a&U7BRCjVA_<IDB@a~6DYk2KCp,W6COt5DDKbbJOs*WXD--6JDlt!3EjDN*QgOrDFEn;CE+Vo.F&E1K0,HBBGbotQGAWQBH7-,74k:QyH}QgKHZ8F4IU.lKcq1khJ0RGKIw8,sJtpY71@jDiKP33IJ@(z20UHTgIvfW50_r^-0vHie1s;GT372Yf2OT)T1?;Vc2:;.gY.}kX3lUig3J<5O4Hsz@a}@tB4+6Vd4is:B5etdhB8.D96A78r5%tq!6#VQUE%oSw7Y%<_77VfN83W0hSOO+!8v&sh8UWFM9S7+UCIIFg9@ie@9t82T+PeJs)w#!i+>SD9,M!p-,nShXf*sdb-JGa3-kq.6--/:L)j_3E.i!)J.+GRD/D#Fn(Z(mq/&r8Q:B4l+:Z;TtvE;t_;5$Mx;XH!^;x$rY$(}OK<Tsk9<v60t>0U1*}@TaC>tH>E>@sYC?OIPonkZHB?<6IO@LgvRz@?wG;HO/?}q(pU}>2.e~L(?u@JEqo~/v-L!I/G.!lXU8iQK7<#HLNC#idlu#*Lr+?jP?@$f9k:$&R,/%8Y%;"

local OpcodeGroupMap = {[815545152]=1235884331,[973473711]=1235884299,[847672770]=1235884361,[985784925]=1235884107,[372764256]=1235884430,[1384458130]=1235884491,[859796097]=1235884044,[167007344]=1235884493,[460313302]=1235884521,[1565148555]=1235884431,[1073800838]=1235884363,[966462354]=1235884039,[1688016180]=1235884032,[1869774906]=1235884034,[1157704]=1235884329,[907568952]=1235884462,[1825595675]=1235884296,[2134545660]=1235884041,[1259112333]=1235884045,[197953801]=1235884494,[1229478529]=1235884335,[1087318195]=1235884334,[851381326]=1235884058,[1210545019]=1235884360,[1996615580]=1235884328,[2057458664]=1235884302,[1155506617]=1235884036,[936961719]=1235884524,[278933876]=1235884456,[1912802238]=1235884457,[2107632083]=1235884107,[1642480275]=1235884072,[1895108987]=1235884078,[813098816]=1235884424,[398657618]=1235884037,[1187886048]=1235884495,[570855539]=1235884107,[1423262419]=1235884297,[2118558696]=1235884040,[1740749632]=1235884075,[498867704]=1235884488,[227101441]=1235884043,[2132039576]=1235884520,[569739345]=1235884035,[736007163]=1235884107,[1647340809]=1235884107,[2142411441]=1235884107,[995834533]=1235884527,[373959475]=1235884104,[987194888]=1235884105,[1668227482]=1235884427,[1607958760]=1235884459,[1731476716]=1235884033,[2017712151]=1235884333,[388556898]=1235884073,[600271095]=1235884523,[1164736491]=1235884059,[1750455029]=1235884425,[540134446]=1235884038,[1706610230]=1235884047,[828401364]=1235884526,[436792871]=1235884046,[672148390]=1235884428,[512768634]=1235884492,[1845743616]=1235884489,[1838836457]=1235884332}
do local DecryptionKeyCopy = DecryptionKey for MapKey, MapValue in pairs(OpcodeGroupMap) do OpcodeGroupMap[MapKey] = bit32.bxor(MapValue, DecryptionKeyCopy) end end

local IntegrityHash = 0
local HashPosition = 0
for BlobIndex = 1, #CodeBlob0 do HashPosition = HashPosition + 1 IntegrityHash = bit32.bxor(IntegrityHash, string.byte(CodeBlob0, BlobIndex) + HashPosition) IntegrityHash = bit32.bxor(IntegrityHash, bit32.lshift(IntegrityHash, 13)) IntegrityHash = bit32.rshift(IntegrityHash, 17) IntegrityHash = bit32.bxor(IntegrityHash, bit32.lshift(IntegrityHash, 5)) end
if IntegrityHash ~= 446520 then DecryptionKey = bit32.bxor(DecryptionKey, 4294967295) end

do local _, PcallResult = pcall(function() error(490934, 0) end) if _ and PcallResult ~= 490934 then DecryptionKey = bit32.bxor(DecryptionKey, 1715357303) end end
if string.sub("nfxmyhaxkzbe", 7, 9) ~= "axk" then DecryptionKey = bit32.bxor(DecryptionKey, 90849908) end
if not rawequal(17367, 17367) then DecryptionKey = bit32.bxor(DecryptionKey,771249360) end
if ({unpack({[5]=85952})})[1] ~= 85952 then DecryptionKey = bit32.bxor(DecryptionKey,1953945915) end

local Protos = {[0]={Code=DecodeCode(CodeBlob0, 1235884298, 304),Numbers=DecodeNumbers("351,352,810,811,43,44,820,821,946,947,789,790,323,324,785,786,920,921,555,556", 20),Strings=DecodeStrings("S5+0&Q(S_>OGpa>P&JovLk4kb9S225LkCD~L>XwI2XjwOR0mg8NI)FaN%W9,2TDduPDDsjR0?>ANlsK~LP-9gUI!Y>OG;h)PeKP!R6,n+Q#DC/Q#F@<MoC:-K_hsvRYC<.OGZgl2S>B$MoC6qOH:u$2/t/vWNZh1Xi;7hZeU,ybq8T>WNdC^U,Ykta0hE.abk4>b7pREW:}g(bO$Y}WN30^b9H<PWpi&@", 180, {5,13,15,147}, 4, 2077715751),UpvalueRefs={},Subprotos={},NumParams=0,IsVararg=true,NumLocals=41}}

local function Call(ProtoId, Args, Upvalues, Env)
    local Proto = Protos[ProtoId]
    local Code = Proto.Code
    local ProtoNumbers = Proto.Numbers
    local Strings = Proto.Strings
    local UpvalueRefs = Proto.UpvalueRefs
    local UpvaluesList = Upvalues or {}
    local UpvalueBoxes = {}
    local RealRegisters = {}
    local Registers = setmetatable({}, {
        __newindex = function(_, Key, Value)
            RealRegisters[Key] = Value
            if UpvalueBoxes[Key] then
                UpvalueBoxes[Key][1] = Value
            end
        end,
        __index = function(_, Key)
            return RealRegisters[Key]
        end,
    })
    local TmpAccumulator = nil
    local StackBase = 0
    local Varargs = {}
    
    local NumParams = Proto.NumParams
    
    do
        local PassedArgs = Args or {}
        for Index = 1, NumParams do 
            Registers[Index] = PassedArgs[Index] 
        end
        if Proto.IsVararg then
            for Index = NumParams + 1, #PassedArgs do 
                Varargs[Index - NumParams] = PassedArgs[Index] 
            end
        end
    end
    
    local ProgramCounter = 1
    local CodeLength = #Code
    
    local TimingStart = os.clock()
    while ProgramCounter <= CodeLength do
        local TimingLoop = os.clock()
        local Opcode = Code[ProgramCounter]
        local ArgA = Code[ProgramCounter + 1]
        local ArgB = Code[ProgramCounter + 2]
        local ArgC = Code[ProgramCounter + 3]
        ProgramCounter = ProgramCounter + 4
    local EncodedDispatch = OpcodeGroupMap[Opcode]
    if EncodedDispatch then
        local DispatchGroup = bit32.rshift(EncodedDispatch, 5)
        local DispatchOpcode = EncodedDispatch % 32
        if DispatchGroup == 0 then
			if DispatchOpcode == 1 then Registers[ArgA] = ProtoNumbers[ArgB]
				do local DiscardRegister29708 = nil end
			elseif DispatchOpcode == 2 then Registers[ArgA] = Strings[ArgB]
				local NeutralUnused88906 = nil
			elseif DispatchOpcode == 3 then if ArgB ~= 0 then Registers[ArgA] = true else Registers[ArgA] = false end
				if false then return 69090 end
			elseif DispatchOpcode == 4 then Registers[ArgA] = nil
				local NeutralUnused75595 = 44
			end
        elseif DispatchGroup == 1 then
			if DispatchOpcode == 1 then local TableRef = Registers[ArgB]; local KeyRef = Registers[ArgC]; Registers[ArgA] = TableRef[KeyRef]
			elseif DispatchOpcode == 2 then Registers[ArgA][Registers[ArgC]] = Registers[ArgB]
			elseif DispatchOpcode == 3 then local TableRef = Registers[ArgB]; local FieldKey = Strings[ArgC]; Registers[ArgA] = TableRef[FieldKey]
				local NeutralUnused18699 = 85
			elseif DispatchOpcode == 4 then local TableRef = Registers[ArgA]; local FieldKey = Strings[ArgC]; TableRef[FieldKey] = Registers[ArgB]
			elseif DispatchOpcode == 5 then Registers[ArgA] = {}
			elseif DispatchOpcode == 6 then Registers[ArgA] = Env[Strings[ArgB]]
				if 79 == 179 then return end
			elseif DispatchOpcode == 7 then local GlobalKey = Strings[ArgB]; Env[GlobalKey] = Registers[ArgA]
				do local DiscardRegister84101 = nil end
			end
        elseif DispatchGroup == 2 then
			if DispatchOpcode == 1 then local JumpTarget = ArgB; ProgramCounter = JumpTarget
			elseif DispatchOpcode == 2 then local ConditionValue = Registers[ArgA]; if ConditionValue ~= nil and ConditionValue ~= false then ProgramCounter = ArgB end
			elseif DispatchOpcode == 3 then if Registers[ArgA] == nil or Registers[ArgA] == false then ProgramCounter = ArgB end
				do local DiscardRegister52330 = nil end
			end
        elseif DispatchGroup == 3 then
			local DiscardRegister = ArgB + ArgC
        elseif DispatchGroup == 4 then
			local _u49237 = table.unpack
			local _r33810 = table.insert
			if DispatchOpcode == 1 then 
            local Func = Registers[ArgA]
            local PassedArgs = {}
            if ArgB < 0 then
                local Index = ArgA + 1
                while Registers[Index] ~= nil do 
                    _r33810(PassedArgs, Registers[Index])
                    Index = Index + 1 
                end
            else
                for Index = 1, ArgB do 
                    PassedArgs[Index] = Registers[ArgA + Index] 
                end
            end
            
            local Result
            if typeof(Func) == typeof(ProtoNumbers) and Func.VmProtoReference ~= nil then 
                Result = { Call(Func.VmProtoReference, PassedArgs, Func.VmUpvalueReference, Func.EnvironmentReference) }
            else 
                Result = { Func(_u49237(PassedArgs)) }
            end
            
            if ArgC < 0 then
                local Index = ArgA
                for Iter = 1, #Result do 
                    Registers[Index] = Result[Iter]
                    Index = Index + 1 
                end
                while Registers[Index] ~= nil do 
                    Registers[Index] = nil
                    Index = Index + 1 
                end
            else
                for Index = 1, ArgC do 
                    Registers[ArgA + Index - 1] = Result[Index] 
                end
            end
        
				local NeutralUnused46623 = nil
			elseif DispatchOpcode == 2 then 
            if ArgB < 0 then
                local Result = {}
                local Index = ArgA
                while Registers[Index] ~= nil do 
                    Result[#Result + 1] = Registers[Index]
                    Index = Index + 1 
                end
                return _u49237(Result)
            else
                local Result = {}
                for Index = 1, ArgB do 
                    Result[Index] = Registers[ArgA + Index - 1] 
                end
                return _u49237(Result)
            end
        
			elseif DispatchOpcode == 3 then 
            local SubProto = Protos[ArgB]
            local SubUpvalues = SubProto.UpvalueRefs
            local NewUpvalues = {}
            for Index = 1, #SubUpvalues do 
                local UpvalueDefinition = SubUpvalues[Index]
                if UpvalueDefinition[1] == 0 then 
                    local BoxKey = UpvalueDefinition[2]
                    if not UpvalueBoxes[BoxKey] then
                        UpvalueBoxes[BoxKey] = { Registers[BoxKey] }
                    end
                    NewUpvalues[Index] = UpvalueBoxes[BoxKey]
                else 
                    NewUpvalues[Index] = UpvaluesList[UpvalueDefinition[2]]
                end 
            end 
            Registers[ArgA] = { VmProtoReference = ArgB, VmUpvalueReference = NewUpvalues, EnvironmentReference = Env }
        
			elseif DispatchOpcode == 4 then local ObjectRef = Registers[ArgB]; local MethodKey = Strings[ArgC]; Registers[ArgA + 1] = ObjectRef; Registers[ArgA] = ObjectRef[MethodKey]
				local NeutralUnused14556 = nil
			elseif DispatchOpcode == 5 then 
            if ArgC < 0 then 
                local Index = ArgA
                for Iter = 1, #Varargs do 
                    Registers[Index] = Varargs[Iter] 
                    Index = Index + 1 
                end 
            else 
                for Index = 1, ArgC do 
                    Registers[ArgA + Index - 1] = Varargs[Index] 
                end 
            end 
        
			elseif DispatchOpcode == 6 then local DiscardValue = nil + 1
			end
        elseif DispatchGroup == 5 then
			local _f52526 = bit32.bnot
			if DispatchOpcode == 1 then local SourceValue = Registers[ArgB]; Registers[ArgA] = -SourceValue
			elseif DispatchOpcode == 2 then Registers[ArgA] = _f52526(Registers[ArgB])
			elseif DispatchOpcode == 3 then Registers[ArgA] = not Registers[ArgB]
				local DiscardRegister = 50 + 52 - 80
			elseif DispatchOpcode == 4 then Registers[ArgA] = #Registers[ArgB]
			end
        elseif DispatchGroup == 6 then
			if DispatchOpcode == 1 then local LeftOperand = Registers[ArgB]; local RightOperand = Registers[ArgC]; Registers[ArgA] = LeftOperand + RightOperand
			elseif DispatchOpcode == 2 then Registers[ArgA] = Registers[ArgB] + (-Registers[ArgC])
			elseif DispatchOpcode == 3 then Registers[ArgA] = Registers[ArgB] * Registers[ArgC]
			elseif DispatchOpcode == 4 then local LeftOperand = Registers[ArgB]; local RightOperand = Registers[ArgC]; Registers[ArgA] = LeftOperand / RightOperand
			elseif DispatchOpcode == 5 then Registers[ArgA] = Registers[ArgB] % Registers[ArgC]
				if false then return 61619 end
			elseif DispatchOpcode == 6 then Registers[ArgA] = Registers[ArgB] ^ Registers[ArgC]
				if 25 == 159 then return end
			elseif DispatchOpcode == 7 then Registers[ArgA] = Registers[ArgB] .. Registers[ArgC]
			end
        elseif DispatchGroup == 7 then
			if DispatchOpcode == 1 then Registers[ArgA] = Registers[ArgB] + ProtoNumbers[ArgC]
			elseif DispatchOpcode == 2 then Registers[ArgA] = Registers[ArgB] - ProtoNumbers[ArgC]
			elseif DispatchOpcode == 3 then Registers[ArgA] = Registers[ArgB] * ProtoNumbers[ArgC]
			elseif DispatchOpcode == 4 then local ConstValue = ProtoNumbers[ArgC]; Registers[ArgA] = Registers[ArgB] / ConstValue
			elseif DispatchOpcode == 5 then local ConstValue = ProtoNumbers[ArgC]; Registers[ArgA] = not ConstValue
				do local DiscardRegister98895 = nil end
			elseif DispatchOpcode == 6 then Registers[ArgA] = -ProtoNumbers[ArgC]
				if nil then error(73512) end
			end
        elseif DispatchGroup == 8 then
			local _y54460 = bit32.bnot
			if DispatchOpcode == 1 then TmpAccumulator = Registers[ArgB]
			elseif DispatchOpcode == 2 then local ResultValue = TmpAccumulator; Registers[ArgA] = ResultValue
			elseif DispatchOpcode == 3 then TmpAccumulator = TmpAccumulator + Registers[ArgC]
			elseif DispatchOpcode == 4 then TmpAccumulator = TmpAccumulator + (-Registers[ArgC])
				local DiscardRegister = 82 + 31 - 66
			elseif DispatchOpcode == 5 then TmpAccumulator = TmpAccumulator * Registers[ArgC]
				if nil then error(35358) end
			elseif DispatchOpcode == 6 then TmpAccumulator = TmpAccumulator / Registers[ArgC]
			elseif DispatchOpcode == 7 then TmpAccumulator = TmpAccumulator % Registers[ArgC]
			elseif DispatchOpcode == 8 then TmpAccumulator = TmpAccumulator ^ Registers[ArgC]
			elseif DispatchOpcode == 9 then TmpAccumulator = TmpAccumulator .. Registers[ArgC]
				if 62 == 199 then return end
			elseif DispatchOpcode == 10 then TmpAccumulator = rawequal(TmpAccumulator, Registers[ArgC])
			elseif DispatchOpcode == 11 then TmpAccumulator = not rawequal(TmpAccumulator, Registers[ArgC])
			elseif DispatchOpcode == 12 then TmpAccumulator = TmpAccumulator < Registers[ArgC]
				local NeutralUnused30098 = 107
			elseif DispatchOpcode == 13 then TmpAccumulator = TmpAccumulator <= Registers[ArgC]
			elseif DispatchOpcode == 14 then TmpAccumulator = -TmpAccumulator
			elseif DispatchOpcode == 15 then TmpAccumulator = not TmpAccumulator
				do local DiscardRegister38055 = nil end
			elseif DispatchOpcode == 16 then TmpAccumulator = _y54460(TmpAccumulator)
				local NeutralUnused57088 = nil
			elseif DispatchOpcode == 17 then TmpAccumulator = #TmpAccumulator
			end
        elseif DispatchGroup == 9 then
			if DispatchOpcode == 1 then local LeftComp = Registers[ArgB]; local RightComp = Registers[ArgC]; Registers[ArgA] = rawequal(LeftComp, RightComp)
				if typeof({}) ~= typeof(true) then end
			elseif DispatchOpcode == 2 then Registers[ArgA] = not rawequal(Registers[ArgB], Registers[ArgC])
				if false then return 91328 end
			elseif DispatchOpcode == 3 then local LeftBound = Registers[ArgB]; local RightBound = Registers[ArgC]; Registers[ArgA] = LeftBound < RightBound
			elseif DispatchOpcode == 4 then local LeftBound = Registers[ArgB]; local RightBound = Registers[ArgC]; Registers[ArgA] = LeftBound <= RightBound
				if 4 == 153 then return end
			end
        elseif DispatchGroup == 10 then
			if DispatchOpcode == 1 then if ArgA ~= ArgB then Registers[ArgA] = Registers[ArgB] end
			elseif DispatchOpcode == 2 then local UpvalueBox = UpvaluesList[ArgB]; Registers[ArgA] = UpvalueBox[1]
			elseif DispatchOpcode == 3 then UpvaluesList[ArgB][1] = Registers[ArgA]
			end
        end
    else
        error(Strings[ 3 ] .. tostring(Opcode))
    end
    if TimingLoop and os.clock() - TimingLoop > 0.1 then ProgramCounter = 0 end
    DecryptionKey = bit32.bxor(DecryptionKey, bit32.lshift(ProgramCounter, 13), Opcode)
end
return
end

local function Run(...)
    local PassedArgs = { ... }
    local Env = getfenv()
    return Call(0, PassedArgs, { Env }, Env)
end

return Run(...)
