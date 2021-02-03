bgNPC.cfg.dialogues = {
   {
      interlocutors = { 'female', 'female', },
      list = {
         { 'vo/npc/female01/hi01.wav' },
         {
            'vo/npc/female01/answer30.wav',
            'vo/npc/female01/gordead_ans01.wav'
         },
         { 'vo/npc/female01/answer40.wav' },
         { 'vo/npc/female01/answer01.wav' },
      },
   },
   {
      interlocutors = { 'male', 'male', },
      list = {
         { 'vo/npc/male01/hi01.wav' },
         { 'vo/npc/male01/hi02.wav' },
         { 'vo/npc/male01/question01.wav' },
         { 'vo/npc/male01/answer04.wav' },
         { 
            'vo/npc/male01/question02.wav',
            'vo/npc/male01/question03.wav'
         },
      },
      animations = {
         { id = 3, sequence = 'LineIdle01', time = 3 },
         { id = 4, sequence = 'Wave_Close' },
         { id = 5, sequence = 'LineIdle02', time = 3 },
      }
   },
   {
      interlocutors = { 'female', 'male', },
      list = {
         { 'vo/npc/female01/pardonme01.wav' },
         { 'vo/npc/male01/answer10.wav' },
         { 'vo/npc/female01/question12.wav' },
         { 'vo/npc/male01/answer15.wav' },
         {
            'vo/npc/female01/question27.wav',
            'vo/npc/female01/question25.wav',
         },
         { 'vo/npc/male01/answer24.wav' },
         { 'vo/npc/female01/sorry01.wav' },
         { 
            'vo/npc/male01/answer36.wav',
            'vo/npc/male01/answer39.wav'
         }
      },
      animations = {
         { id = 3, sequence = 'LineIdle01', time = 3 },
         { id = 4, sequence = 'Wave_Close' },
         { id = 7, sequence = 'LineIdle02', time = 3 },
      }
   },
}