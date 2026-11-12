-- Build-time AST transforms; this file is never included in the addon.
return function(minifier)
  local allowed = {
    math = { 'abs', 'acos', 'asin', 'atan', 'atan2', 'ceil', 'cos', 'deg', 'exp', 'floor', 'fmod', 'log', 'max', 'min', 'modf', 'pow', 'rad', 'random', 'sin', 'sqrt', 'tan' },
    string = { 'byte', 'char', 'find', 'format', 'gmatch', 'gsub', 'len', 'lower', 'match', 'rep', 'reverse', 'sub', 'upper' },
    table = { 'concat', 'insert', 'remove', 'sort' }
  }
  for _, members in pairs(allowed) do
    for _, member in ipairs(members) do members[member] = true end
  end

  local function collect(ast)
    local nodes, seen = {}, {}
    local function walk(value)
      if type(value) ~= 'table' or seen[value] then return end
      seen[value] = true
      nodes[#nodes + 1] = value
      for _, child in pairs(value) do walk(child) end
    end
    walk(ast)
    return nodes
  end

  local function localize(ast, nodes)
    minifier.AddVariableInfo(ast)
    local calls, field_bases, blocked, names = {}, {}, {}, {}
    for _, node in ipairs(nodes) do
      if node.Type == 'Ident' then names[node.Source] = true end
      if node.Type == 'FieldExpr' then field_bases[node.Base] = true end
      if node.Type == 'VariableExpr' and node.Variable.Type == 'Global' then
        local name = node.Token.Source
        if name == '_G' or name == 'debug' or name == 'getfenv' or name == 'setfenv' or name == 'rawset' then return 0 end
        if node.Variable.AssignedTo then blocked[name] = true end
      end
      if node.Type == 'CallExpr' and node.Base.Type == 'FieldExpr' then
        local field = node.Base
        if field.Base.Type == 'VariableExpr' and field.Base.Variable.Type == 'Global' then
          local library, member = field.Base.Token.Source, field.Field.Source
          if allowed[library] and allowed[library][member] then
            local key = library .. '.' .. member
            calls[key] = calls[key] or { library = library }
            table.insert(calls[key], field)
          end
        end
      end
      if node.Type == 'AssignmentStat' then
        for _, lhs in ipairs(node.Lhs) do
          while lhs.Base do lhs = lhs.Base end
          if lhs.Variable and lhs.Variable.Type == 'Global' then blocked[lhs.Token.Source] = true end
        end
      end
    end
    -- A library passed around as a value could be mutated through that alias.
    for _, node in ipairs(nodes) do
      if node.Type == 'VariableExpr' and node.Variable.Type == 'Global' and not field_bases[node] then
        blocked[node.Token.Source] = true
      end
    end
    local keys = {}
    for key, fields in pairs(calls) do
      if #fields > 1 and not blocked[fields.library] then keys[#keys + 1] = key end
    end
    table.sort(keys)
    local declarations = {}
    for index, key in ipairs(keys) do
      local name = '_bgn_build_' .. index
      while names[name] do name = name .. '_' end
      names[name] = true
      declarations[#declarations + 1] = 'local ' .. name .. '=' .. key .. ';'
      for _, field in ipairs(calls[key]) do
        field.Type = 'VariableExpr'
        field.Token = { Type = 'Ident', Source = name, LeadingWhite = field.Base.Token.LeadingWhite }
      end
    end
    return #keys, table.concat(declarations)
  end

  return function(source)
    local ast = minifier.CreateLuaParser(source)
    local nodes = collect(ast)
    for _, node in ipairs(nodes) do
      if node.Type == 'StringLiteral' and node.Token.Source:find('[\r\n]') then
        -- Preserve literal bytes while moving long strings onto one physical line.
        local value = assert(loadstring('return ' .. node.Token.Source))()
        node.Token.Source = string.format('%q', value):gsub('\\\n', '\\n'):gsub('\r', '\\r')
      end
    end
    local cached, prefix = localize(ast, nodes)
    ast = minifier.CreateLuaParser((prefix or '') .. minifier.AstToString(ast))
    local globals, scope = minifier.AddVariableInfo(ast)
    minifier.MinifyVariables(globals, scope)
    minifier.StripAst(ast)
    local result = minifier.AstToString(ast)
    if result == '' then result = 'return' end -- GMad rejects zero-byte files.
    assert(not result:find('[\r\n]'), 'Minifier produced multiple physical lines')
    return result, cached
  end
end
