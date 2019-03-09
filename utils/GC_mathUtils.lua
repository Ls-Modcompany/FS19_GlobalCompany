-- 
-- GlobalCompany - MathUtils
-- 
-- @Interface: --
-- @Author: LS-Modcompany
-- @Date: 26.02.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
-- 	v1.0.0.0 (26.02.2019):
-- 		- initial fs19 (aPuehri)
-- 
-- Notes:
-- 
-- 
-- ToDo:
--
-- 

GlobalCompanyMathUtils = {};
g_company.mathUtils = GlobalCompanyMathUtils;

function GlobalCompanyMathUtils.sign(v)
	return (v >= 0 and 1) or -1
end

function GlobalCompanyMathUtils.round(v, bracket)
	bracket = bracket or 1;
	return math.floor(v/bracket + GlobalCompanyMathUtils.sign(v) * 0.5) * bracket;
end;