-- 
-- GlobalCompany - Utils - GC_cameraUtil
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 26.01.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 ():
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
--      - some functions from Stegei and Mixfeeder(Fs15)
-- 
-- ToDo:
-- 
-- 
local debugIndex = g_debug.registerMod("GlobalCompany-GC_cameraUtil");

GC_cameraUtil = {};
g_company.cameraUtil = GC_cameraUtil;

function GC_cameraUtil:load()	
	
end;

function GC_cameraUtil:getRenderOverlayId(camera, x, y)	
    local cameraAspectRatio, cameraResolutionX, cameraResolutionY = GC_cameraUtil:getCameraData(x,y);
    local shapesMask = 255 --0x000000FF
    local lightsMask = 16711680 -- 0x00FF0000
    return createRenderOverlay(camera, cameraAspectRatio, cameraResolutionX, cameraResolutionY, true, shapesMask, lightsMask);
end;

function GC_cameraUtil:getCameraData(x,y)	
    local cameraAspectRatio = getScreenAspectRatio() * ((g_screenWidth*x)/(g_screenHeight*y));
    
	local cameraResolutionX = GC_cameraUtil:nextPow2(g_screenWidth*x);
    local cameraResolutionY = GC_cameraUtil:nextPow2(g_screenHeight*y);

    --local cameraResolutionX = math.ceil(g_screenWidth * x) * 2
    --local cameraResolutionY = math.ceil(g_screenHeight * y) * 2

    return cameraAspectRatio, cameraResolutionX, cameraResolutionY;
end;

function GC_cameraUtil:nextPow2(x)
    local rval = 1;
    while rval < x do
        rval = rval*2;
    end
    return rval;
end;

