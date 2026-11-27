describe('kiro config', function()
  local config = require('kiro.config')
  local kiro = require('kiro')

  before_each(function()
    config.reset()
    vim.g.kiro_chat_width = nil
    vim.g.kiro_agent = nil
    vim.g.kiro_no_mappings = nil
  end)

  it('has defaults', function()
    assert.are.same({ chat_width = 65, agent = 'nvim-reviewer', mappings = true }, kiro.config())
  end)

  it('lets g: variables override defaults', function()
    vim.g.kiro_chat_width = 80
    vim.g.kiro_agent = 'kiro_default'
    assert.are.equal(80, kiro.config().chat_width)
    assert.are.equal('kiro_default', kiro.config().agent)
  end)

  it('lets setup() override g: variables', function()
    vim.g.kiro_chat_width = 80
    kiro.setup({ chat_width = 90 })
    assert.are.equal(90, kiro.config().chat_width)
  end)

  it('can be called twice and merges options', function()
    kiro.setup({ chat_width = 90 })
    kiro.setup({ agent = 'x' })
    assert.are.same({ chat_width = 90, agent = 'x', mappings = true }, kiro.config())
  end)

  it('works without setup() and picks up late g: changes', function()
    assert.are.equal(65, kiro.config().chat_width)
    vim.g.kiro_chat_width = 70
    assert.are.equal(70, kiro.config().chat_width)
  end)

  it('honours g:kiro_no_mappings', function()
    vim.g.kiro_no_mappings = 1
    assert.is_false(kiro.config().mappings)
    vim.g.kiro_no_mappings = 0
    assert.is_true(kiro.config().mappings)
  end)

  it('setup({mappings = false}) beats g:kiro_no_mappings = 0', function()
    vim.g.kiro_no_mappings = 0
    kiro.setup({ mappings = false })
    assert.is_false(kiro.config().mappings)
  end)

  it('rejects a non-table setup argument', function()
    assert.has_error(function()
      kiro.setup('nope')
    end)
  end)
end)
