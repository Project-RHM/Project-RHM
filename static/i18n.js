/* Interface-only translations: grammar source, generated math and answers stay intact. */
(() => {
    const zh = {
        'Question workspace':'出题工作台', 'New question':'新建题目', 'Question library':'题型库',
        'My presets':'我的预设', 'Recent generations':'生成记录', 'Classic generator':'经典生成器',
        'Classic settings':'经典生成器设置', 'Search question types':'搜索题型',
        'Question settings':'题目设置', 'Configure':'配置出题', 'Rhema source':'编写语法',
        'Question type':'题型', 'Question form':'子题型', 'Number of questions':'生成数量',
        'Advanced settings':'高级设置', 'Output settings':'输出设置', 'Output':'输出',
        'Save as':'预设名称', 'Additional instruction':'附加要求', 'Answer box width':'答案框宽度',
        'Reset settings':'恢复默认', 'Export specification':'导出规范', 'Save preset':'保存预设',
        'Generate questions':'生成题目', 'Student ID (optional for Rhema)':'学生编号（Rhema 可选）',
        'Optional student ID':'学生编号，可选', 'Question preview':'题目预览',
        'Student ID':'学生编号',
        'No questions generated':'尚未生成题目', 'Questions':'题目', 'Generation tree':'生成树',
        'Productions / Attributes':'规则与属性', 'AST / DCST Trees':'AST / DCST 树',
        'Checking renderer':'正在检查渲染服务', 'WeBWorK connected':'WeBWorK 已连接',
        'WeBWorK offline':'WeBWorK 未连接', 'Rendering with WeBWorK...':'正在通过 WeBWorK 渲染...',
        'Rendered by WeBWorK':'由 WeBWorK 渲染', 'Refresh preview':'刷新预览',
        'Check answers':'检查答案', 'Checking answers...':'正在检查答案...',
        'Answer results':'答案结果', 'Correct':'正确', 'Incorrect':'错误', 'Partially correct':'部分正确',
        'Answers changed. Check again.':'答案已更改，请重新检查。',
        'Could not read answer inputs. Refresh the preview.':'无法读取答案，请刷新预览。',
        'Local preview':'本地预览', 'Local preview - not rendered by WeBWorK':'本地预览，非 WeBWorK 渲染',
        'WeBWorK is offline. Start the renderer and refresh.':'WeBWorK 未连接，请启动 renderer 后刷新。',
        'Source changed. Refresh the preview.':'源代码已更改，请刷新预览。',
        'Standard answers':'标准答案', 'Settings changed':'设置已更改', 'Generated successfully':'生成成功',
        'Default settings':'默认配置', 'Saved preset':'已保存的预设', 'Loading settings':'正在加载配置',
        'Source mode available':'请使用代码模式', 'Generation budget':'生成预算',
        'Complexity budget':'复杂度预算', 'Budget preset':'预算预设', 'Custom':'自定义',
        'Lower budget':'较低预算', 'Default':'默认', 'Higher budget':'较高预算',
        'Question parameters':'题型参数', 'Random values':'数值范围', 'Expression operators':'表达式运算符数量',
        'Minimum (optional)':'最少，可选', 'Maximum (optional)':'最多，可选', 'No limit':'不限制',
        'Minimum':'最小值', 'Maximum':'最大值', 'Digits':'位数',
        'Question forms and rule settings':'题目形式与生成规则', 'Expression leaf ranges':'表达式叶节点范围',
        'Leaf values':'叶节点数值', 'Weight':'权重', 'Cost':'消耗预算', 'Generated Rhema':'生成的 Rhema 规范',
        'First term':'首项', 'Common difference':'公差', 'Common ratio':'公比', 'Term index':'项数',
        'Maximum digits':'最大位数', 'Matrix dimension':'矩阵维数', 'Evaluation point':'求值点',
        'Exponent':'指数', 'Question mode':'题型模式', 'Calculus mode':'微积分模式',
        'Vector mode':'向量模式', 'Set mode':'集合模式', 'Root':'根', 'Second root':'第二个根',
        'Mixed':'混合', 'Union':'并集', 'Intersection':'交集', 'Difference':'差集',
        'Random':'随机', 'True':'真', 'False':'假', 'Derivative':'导数', 'Integral':'积分',
        'Dot product':'点积', 'Cross product':'叉积', 'Magnitude':'模长', 'Unit vector':'单位向量',
        'Parallel vector':'平行向量', 'Same direction':'同向', 'Conjugate':'共轭', 'Modulus':'模',
        'Power of i':'i 的幂', 'Arithmetic':'算术', 'Sequences':'数列',
        'Arithmetic sequence: nth term':'等差数列求项', 'Geometric sequence: nth term':'等比数列求项',
        'Arithmetic sequence: sum':'等差数列求和', 'Geometric sequence: sum':'等比数列求和',
        'Boolean evaluation':'布尔表达式求值', 'Boolean equivalence':'布尔表达式等价',
        'Calculus':'微积分', 'Complex numbers':'复数', 'Counting and probability':'计数与概率',
        'Calculus and logic':'微积分与逻辑', 'Determinants':'行列式', 'Eigenvalues and eigenvectors':'特征值与特征向量',
        'Polynomial factoring':'多项式因式分解', 'Inequalities':'不等式', 'Formula operations':'公式运算',
        'Linear equations: fixed forms':'一次方程：固定形式', 'Polynomial operations':'多项式运算',
        'Quadratic equations':'二次方程', 'Limits':'极限', 'Linear equations: expressions':'一次方程：表达式',
        'Linear systems':'线性方程组', 'Logic: classification and transformations':'逻辑分类与变换',
        'Matrix expressions':'矩阵表达式', 'Matrix inverses':'逆矩阵', 'Number theory':'数论',
        'Polynomial expansion':'多项式展开', 'Expansion and factoring':'展开与因式分解',
        'Sequences: two-part questions':'数列：多部分题目', 'Series':'级数', 'Set operations':'集合运算',
        'Vector operations':'向量运算', 'Vector expressions':'向量表达式',
        'Arithmetic and algebra':'算术与代数', 'Logic and sets':'逻辑与集合',
        'Calculus and sequences':'微积分与数列', 'Vectors and linear algebra':'向量与线性代数',
        'Other topics':'其他题型', 'No matching question types':'没有匹配的题型',
        'Edit Grammar':'编辑语法', 'Hide Grammar':'收起语法', 'New Grammar':'新建语法',
        'File name':'文件名', 'Create Draft':'创建草稿', 'Cancel':'取消', 'Reload':'重新加载',
        'Check':'检查', 'Save':'保存', 'Saved':'已保存', 'Unsaved changes':'未保存',
        'Generated PGML':'生成的 PGML', 'Read-only until edit mode is enabled':'只读',
        'Copy PGML Code':'复制 PGML', 'Activate Edit Mode':'编辑 PGML', 'Save Changes':'保存修改',
        'Generation failed':'生成失败', 'Generating your question set':'正在生成题目',
        'Building PGML and validating the output…':'正在生成 PGML 并检查输出...',
        'Back to generator':'返回出题', 'Generation history':'生成记录', 'Question set':'题目集',
        'Saved output':'保存的输出', 'Saved PGML':'已保存的 PGML', 'Open edit mode to make changes':'只读',
        'Add context to arithmetic questions':'为算术题添加情境', 'Set API key':'设置 API key',
        'Save API Key':'保存 API key', 'Edit API Key':'修改 API key', 'API key configured':'已配置 API key',
        'Switch language':'切换语言', 'Collapse history sidebar':'折叠侧栏', 'Collapse sidebar':'折叠侧栏',
        'Resize settings and preview':'调整设置区和预览区宽度', 'Resize panels':'调整面板宽度',
        'Expand history sidebar':'展开侧栏', 'Expand sidebar':'展开侧栏',
        'Checking and saving':'正在检查并保存', 'Checking export':'正在检查导出', 'Preset saved':'预设已保存',
        'Exported':'已导出', 'Check settings':'请检查配置', 'Specification exported.':'规范已导出。',
        'Two integer roots':'两个整数根', 'Repeated root':'重根', 'No real roots':'无实根',
        'Two rational roots':'两个有理根', '2 x 2 eigenvalues':'二阶矩阵特征值', '3 x 3 eigenvalues':'三阶矩阵特征值',
        'Characteristic polynomial':'特征多项式', 'Eigenvector':'特征向量',
        'Save the source draft before switching to the form editor.':'请先保存语法草稿，再切换至配置出题。'
    };
    const reverse = new Map(Object.entries(zh).map(([key,value]) => [value,key]));
    let language = 'en';
    try {language = localStorage.getItem('rhema.language') === 'zh' ? 'zh' : 'en';} catch {}
    const blocked = 'script,style,textarea,pre,code,iframe,[data-no-translate],.katex,.rhema-highlight,.rhema-line-numbers';
    function english(value) {
        if (/^\d+ 道题$/.test(value)) return value.replace(' 道题', ' questions');
        const random = value.match(/^数值范围（(\d+)）$/);
        if (random) return `Random values (${random[1]})`;
        const score = value.match(/^得分：(\d+)%（(\d+)\/(\d+) 正确）$/);
        if (score) return `Score: ${score[1]}% (${score[2]}/${score[3]} correct)`;
        return reverse.get(value) || value;
    }
    function translate(value) {
        const key = english(value);
        if (language === 'en') return key;
        if (zh[key]) return zh[key];
        const count = key.match(/^(\d+) questions$/);
        if (count) return `${count[1]} 道题`;
        const random = key.match(/^Random values \((\d+)\)$/);
        if (random) return `数值范围（${random[1]}）`;
        const score = key.match(/^Score: (\d+)% \((\d+)\/(\d+) correct\)$/);
        if (score) return `得分：${score[1]}%（${score[2]}/${score[3]} 正确）`;
        return key;
    }
    const originalText = new WeakMap();
    const originalAttrs = new WeakMap();
    function apply() {
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        let text;
        while ((text = walker.nextNode())) {
            if (text.parentElement?.closest(blocked)) continue;
            const current = text.textContent;
            const previous = originalText.get(text);
            const base = previous && (current === previous || current === translate(previous) || current === (zh[previous] || previous)) ? previous : english(current.trim());
            originalText.set(text, base);
            const next = current.replace(current.trim(), translate(base));
            if (next !== current) text.textContent = next;
        }
        document.querySelectorAll('[placeholder],[title],[aria-label]').forEach(element => {
            if (element.closest(blocked)) return;
            const attrs = originalAttrs.get(element) || {};
            for (const name of ['placeholder','title','aria-label']) {
                if (!element.hasAttribute(name)) continue;
                const current = element.getAttribute(name);
                const previous = attrs[name];
                const base = previous && (current === previous || current === translate(previous) || current === zh[previous])
                    ? previous : english(current);
                attrs[name] = base;
                const next = translate(base);
                if (current !== next) element.setAttribute(name, next);
            }
            originalAttrs.set(element, attrs);
        });
        document.documentElement.lang = language === 'zh' ? 'zh-CN' : 'en';
        const button = document.getElementById('languageToggle');
        if (button && button.textContent !== (language === 'en' ? '中文' : 'English')) button.textContent = language === 'en' ? '中文' : 'English';
    }
    let scheduled = false;
    function schedule() {
        if (scheduled) return;
        scheduled = true; requestAnimationFrame(() => {scheduled = false; apply();});
    }
    document.addEventListener('DOMContentLoaded', () => {
        document.getElementById('languageToggle').addEventListener('click', () => {
            language = language === 'en' ? 'zh' : 'en';
            try {localStorage.setItem('rhema.language', language);} catch {}
            apply(); document.dispatchEvent(new Event('rhema:language'));
        });
        new MutationObserver(schedule).observe(document.body, {subtree:true, childList:true, characterData:true});
        apply();
    });
    window.RhemaI18n = {t:translate, language:() => language};
})();
