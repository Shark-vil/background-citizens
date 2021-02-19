bgNPC.cfg.dialogues = {
   {
      interlocutors = { 'citizen', 'citizen', },
      gender = { 'any', 'any', },
      list = {
         { 'vo/npc/%gender%01/hi01.wav' },
         {
            'vo/npc/%gender%01/answer30.wav',
            'vo/npc/%gender%01/gordead_ans01.wav'
         },
         { 'vo/npc/%gender%01/answer40.wav' },
         { 'vo/npc/%gender%01/answer01.wav' },
      },
   },
   {
      interlocutors = { 'citizen', 'citizen', },
      gender = { 'any', 'any', },
      list = {
         { 'vo/npc/%gender%01/hi01.wav' },
         { 'vo/npc/%gender%01/hi02.wav' },
         { 'vo/npc/%gender%01/question01.wav' },
         { 'vo/npc/%gender%01/answer04.wav' },
         { 
            'vo/npc/%gender%01/question02.wav',
            'vo/npc/%gender%01/question03.wav'
         },
      },
      animations = {
         { id = 3, sequence = 'LineIdle01', time = 3 },
         { id = 4, sequence = 'Wave_Close' },
         { id = 5, sequence = 'LineIdle02', time = 3 },
      }
   },
   {
      interlocutors = { 'citizen', 'citizen', },
      gender = { 'female', 'any', },
      list = {
         { 'vo/npc/female01/pardonme01.wav' },
         { 'vo/npc/%gender%01/answer10.wav' },
         { 'vo/npc/female01/question12.wav' },
         { 'vo/npc/%gender%01/answer15.wav' },
         {
            'vo/npc/female01/question27.wav',
            'vo/npc/female01/question25.wav',
         },
         { 'vo/npc/%gender%01/answer24.wav' },
         { 'vo/npc/female01/sorry01.wav' },
         { 
            'vo/npc/%gender%01/answer36.wav',
            'vo/npc/%gender%01/answer39.wav'
         }
      },
      animations = {
         { id = 3, sequence = 'LineIdle01', time = 3 },
         { id = 4, sequence = 'Wave_Close' },
         { id = 7, sequence = 'LineIdle02', time = 3 },
      }
   },
   {
      interlocutors = { 'citizen', 'citizen', },
      gender = { 'any', 'any', },
      list = {
         { 'vo/npc/%gender%01/sorry02.wav' },
         { 'vo/npc/%gender%01/hi01.wav' },
         { 'vo/npc/%gender%01/question23.wav' },
         { 'vo/npc/%gender%01/answer19.wav' },
         { 'vo/npc/%gender%01/answer32.wav' },
         { 'vo/npc/%gender%01/answer16.wav' },
      },
      animations = {
         { id = 3, sequence = 'LineIdle01', time = 3 },
         { id = 5, sequence = 'LineIdle02', time = 3 },
         { id = 6, sequence = 'Wave_Close' },
      }
   },
   {
      interlocutors = { 'police', 'gangster', },
      gender = { 'none', 'any', },
      list = {
         { 'npc/metropolice/vo/citizen.wav' },
         { 'vo/npc/%gender%01/hi01.wav' },
         { 'npc/metropolice/vo/holdit.wav' },
         { 'vo/npc/%gender%01/answer25.wav' },
         { 'npc/metropolice/vo/xray.wav' },
         { 'vo/npc/%gender%01/answer20.wav' },
         { 
            'npc/overwatch/radiovoice/illegalcarrying95.wav',
            'npc/metropolice/vo/gotsuspect1here.wav',
            'npc/metropolice/vo/code7.wav',
         },
         { 'vo/npc/%gender%01/question25.wav' },
         { 'npc/metropolice/vo/getdown.wav' },
         { 'vo/npc/%gender%01/answer11.wav' },
      },
      animations = {
         { id = 3, sequence = 'Harassfront2' },
         { id = 5, sequence = 'Canal5bidle1', time = 4 },
         { id = 6, sequence = 'LineIdle02' },
         { id = 9, sequence = 'Harassfront1' },
      },
      finalAction = function(actor1, actor2)
         if not actor1:IsAlive() or not actor2:IsAlive() then return end
         actor2:AddTarget(actor1:GetNPC())
         actor2:Defense()
      end
   },
}