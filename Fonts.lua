local FontStrings={}
local FontFile
local SM = LibStub:GetLibrary("LibSharedMedia-3.0")

-- Performance: Cache global functions as locals
local tgetn = table.getn

SM:Register(SM.MediaType.FONT, 'Big Noodle Titling', [[Interface\AddOns\Spy\Fonts\BigNoodleTitling.ttf]])
SM:Register(SM.MediaType.FONT, 'Express Way', [[Interface\AddOns\Spy\Fonts\Expressway.ttf]])
SM:Register(SM.MediaType.FONT, 'Myriad Cond', [[Interface\AddOns\Spy\Fonts\MyriadPro-Cond.ttf]])

function Spy:AddFontString(string)
	local Font, Height, Flags

	FontStrings[tgetn(FontStrings)+1] = string

	if not FontFile and Spy.db.profile.Font then
		FontFile = SM:Fetch("font", Spy.db.profile.Font)
	end

	if FontFile then
		Font, Height, Flags = string:GetFont()
		if Font ~= FontFile then
			string:SetFont(FontFile, Height, Flags)
		end
	end
end

function Spy:SetFont(fontname)
	local Height, Flags

	Spy.db.profile.Font = fontname
	FontFile = SM:Fetch("font",fontname)

	for i = 1 , tgetn(FontStrings) do
		_, Height, Flags = FontStrings[i]:GetFont()
		FontStrings[i]:SetFont(FontFile, Height, Flags)
	end
end
