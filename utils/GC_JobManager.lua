-- 
-- GlobalCompany - Job Manager
-- 
-- @Interface: 1.4.0.0 b5008
-- @Author: LS-Modcompany
-- @Date: 14.09.2019
-- @Version: 1.0.0.0
-- 
-- @Support: LS-Modcompany
-- 
-- Changelog:
--		
--
-- 	v1.0.0.0 (14.09.2019):
-- 		- initial fs19 (kevink98)
-- 
-- Notes:
--
--
-- ToDo:
--
-- 


GC_JobManager = {};
GC_JobManager.debugIndex = g_company.debug:registerScriptName("GC_JobManager")

local GC_JobManager_mt = Class(GC_JobManager)

GC_JobManager.TYPE_MAP = 1

function GC_JobManager:new()
    local self = {}
	setmetatable(self, GC_JobManager_mt)

    self.debugData = g_company.debug:getDebugData(GC_JobManager.debugIndex)

    self.jobId = 0 -- based 1
    self.jobs = {}

    g_company.addUpdateable(self, self.update);	
	return self
end;

function GC_JobManager:getNextId()
    self.jobId = self.jobId + 1
    return self.jobId
end;

function GC_JobManager:addJob_Map(func, target, terrainSize, size, width, height, loops)
    local newJob = {}
    newJob.id = self:getNextId()

    newJob.type = GC_JobManager.TYPE_MAP

    newJob.isActive = false
    -- newJob.needRun = false

    newJob.runCounter = 0;

    newJob.func = func
    newJob.target = target
    newJob.terrainSize = terrainSize
    newJob.size = size
    newJob.width = Utils.getNoNil(width, 32)
    newJob.height = Utils.getNoNil(height, 32)
    newJob.loops = Utils.getNoNil(loops, 1)

    newJob.currentState_max = size * size
    newJob.currentState_step = newJob.width * newJob.height * newJob.loops
    newJob.currentState_timer = 0
    newJob.currentState_timerPrint = 0

    table.insert(self.jobs, newJob)

    return newJob.id
end

function GC_JobManager:removeJob(id)
    local index = -1
    for k, job in pairs(self.jobs) do
        if job.id == id then
            index = k
            break
        end
    end
    if index > -1 then
        table.remove(self.jobs, index)
    end
end

function GC_JobManager:startJob(jobId)
    for _,job in pairs(self.jobs)do
        if job.id == jobId then
            if job.type == GC_JobManager.TYPE_MAP then
                job.x = 0
                job.z = 0
            end
            job.runCounter = job.runCounter + 1
            job.isActive = true
            return
        end
    end
end

function GC_JobManager:update(dt)
    for _,job in pairs(self.jobs)do
        if job.isActive then          
            if job.type == GC_JobManager.TYPE_MAP then  
                for i=1, job.loops do
                    local pixelSize = job.terrainSize / job.size

                    local startWorldX = job.x * job.width - job.terrainSize / 2 + pixelSize
                    local startWorldZ = job.z * job.height - job.terrainSize / 2 + pixelSize
                    local widthWorldX = startWorldX + job.width - pixelSize * 2
                    local widthWorldZ = startWorldZ
                    local heightWorldX = startWorldX
                    local heightWorldZ = startWorldZ + job.height - pixelSize * 2

                    job.func(job.target, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
                    
                    if job.x < (job.size / job.width) - 1 then
                        job.x = job.x + 1
                    elseif job.z < (job.size / job.height) - 1 then
                        job.z = job.z + 1
                        job.x = 0
                    else
                        job.runCounter = job.runCounter - 1
                        job.x = 0
                        job.z = 0
                        if job.runCounter == 0 then
                            job.isActive = false
                        end
                    end
                end
                local oldTimerP = job.currentState_timerP
                
                job.currentState_timer = job.currentState_timer + job.currentState_step
                job.currentState_timerP = job.currentState_timer / job.currentState_max
                if job.currentState_timerP ~= oldTimerP then
                   -- print(job.currentState_timerP)
                end

            end
        end
    end
end