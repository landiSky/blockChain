// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
这个项目是一个多池质押（Staking）合约系统，主要用于：

支持用户在区块链上质押原生币（如 ETH）或任意 ERC20 代币。
项目方可以灵活创建多个质押池，每个池可以设置不同的质押代币、奖励分配规则等。
用户质押后，根据质押数量和时间获得奖励代币（如 MetaNodeToken）。
合约支持升级、权限管理和安全控制，适合 DeFi、社区激励等场景。
简而言之：
这是一个可扩展的区块链质押奖励平台，方便项目方和用户进行多币种质押和奖励分配。

核心质押合约，支持多池，每个池可配置质押代币（原生币或 ERC20）、奖励分配规则等。
管理用户质押、解除质押、奖励领取等逻辑。
支持合约升级（UUPS）、权限控制（AccessControl）、暂停功能（Pausable）。
*/
// 引入 ERC20 标准代币的接口 让你的合约可以与任何符合 ERC20 标准的代币进行交互（如转账、授权、查询余额等）。
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// 引入 SafeERC20 库，提供安全的 ERC20 操作方法。可以防止因某些 ERC20 合约实现不规范导致的转账失败或安全漏洞（如 safeTransfer、safeTransferFrom 等）。
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// 引入 Address 工具库。提供地址类型的辅助函数，比如判断一个地址是否为合约、发送 ETH、安全调用等。
import "@openzeppelin/contracts/utils/Address.sol";
// 引入 Math 数学库。提供安全的数学运算方法，比如最大值、最小值、平均值、安全乘除法等，防止溢出和精度问题。
import "@openzeppelin/contracts/utils/math/Math.sol";
// 让合约支持“初始化函数”而不是构造函数，适用于可升级合约。这样合约部署后可以通过 initialize 方法设置初始参数。
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// 让合约支持 UUPS（可升级代理）模式。这样你可以后续升级合约逻辑，而不改变合约地址和数据。
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// 让合约支持“暂停/恢复”功能。管理员可以随时暂停合约的关键操作（如质押、提现、领取奖励），用于应急或维护。
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// 提供灵活的角色权限管理系统。你可以为不同账户分配不同权限（如管理员、升级者），控制谁能执行哪些操作。
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// 继承可升级、权限控制、可暂停等功能
contract MetaNodeStake is
    Initializable,   
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    // ************************************** INVARIANT **************************************

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    uint256 public constant ETH_PID = 0;

    // ************************************** DATA STRUCTURE **************************************
    /*
    Basically, any point in time, the amount of MetaNodes entitled to a user but is pending to be distributed is:

    pending MetaNode = (user.stAmount * pool.accMetaNodePerST) - user.finishedMetaNode

    Whenever a user deposits or withdraws staking tokens to a pool. Here's what happens:
    1. The pool's `accMetaNodePerST` (and `lastRewardBlock`) gets updated.
    2. User receives the pending MetaNode sent to his/her address.
    3. User's `stAmount` gets updated.
    4. User's `finishedMetaNode` gets updated.
    */
    struct Pool {
        // Address of staking token 质押代币的地址
        // 质押池所用的代币地址。
        // 如果是第一个池，通常为 address(0)，表示原生币（如 ETH）；
        // 其他池可以是任意 ERC20 代币的合约地址。
        address stTokenAddress;
        // Weight of pool 不同资金池所占的权重
        // 该池的权重。
        // 决定了该池在所有池中分配奖励的比例，权重越高，获得的奖励越多。
        uint256 poolWeight;
        // Last block number that MetaNodes distribution occurs for pool 
        // 上一次分配奖励的区块号。
        // 用于计算从上次分配到现在应发放多少奖励。
        uint256 lastRewardBlock;
        // Accumulated MetaNodes per staking token of pool
        // 每个质押代币累计获得的 MetaNode 奖励数量（精度放大，通常乘以 1e18）。
        // 用于精确计算每个用户的奖励。
        uint256 accMetaNodePerST;
        // Staking token amount
        // 当前池中所有用户质押的代币总量。
        uint256 stTokenAmount;
        // Min staking amount
        // 用户在该池最小质押金额。 可以为 0，表示不限制最小质押。
        uint256 minDepositAmount;
        // Withdraw locked blocks
        // 用户发起解除质押后，需要等待的区块数。在这段时间内资金被锁定，不能立即提取，提升安全性。
        uint256 unstakeLockedBlocks;
    }
    // 用户的解除质押请求
    struct UnstakeRequest {
        // Request withdraw amount
        // 解除质押请求的数量，也就是用户本次想要解押（取回）的质押代币数量。
        uint256 amount;
        // The blocks when the request withdraw amount can be released
        // 本次解押请求可以被释放（提现）的区块号。
        // 只有当区块高度大于等于 unlockBlocks 时，用户才能真正提取这部分资金，实现了解押的“锁定期”功能。
        uint256 unlockBlocks;
    }
    // 用户质押信息 
    // 这个结构体完整记录了用户在某个质押池的本金、奖励、可领取奖励和所有解押请求，是用户所有质押相关状态的核心数据
    struct User {
        // 记录用户相对每个资金池 的质押记录
        // Staking token amount that user provided
        // 用户当前在该池质押的代币总数量。代表用户实际锁定在合约里的本金。
        uint256 stAmount;
        // Finished distributed MetaNodes to user 最终 MetaNode 得到的数量
        // 用户已经领取或累计获得的 MetaNode 奖励数量。 用于奖励计算，防止重复发放。
        uint256 finishedMetaNode;
        // Pending to claim MetaNodes 当前可取数量
        // 用户当前可以领取但还未领取的 MetaNode 奖励数量。代表用户随时可以提取的奖励余额。
        uint256 pendingMetaNode;
        // Withdraw request list
        // 用户的解押请求列表。每个元素记录一次解押操作的数量和解锁区块号，实现分批解押和锁定期功能。
        UnstakeRequest[] requests;
    }

    // ************************************** STATE VARIABLES **************************************
    // First block that MetaNodeStake will start from
    uint256 public startBlock; // 质押开始区块高度
    // First block that MetaNodeStake will end from
    uint256 public endBlock; // 质押结束区块高度
    // MetaNode token reward per block
    uint256 public MetaNodePerBlock; // 每个区块高度，MetaNode 的奖励数量

    // Pause the withdraw function
    bool public withdrawPaused; // 是否暂停提现
    // Pause the claim function
    // 是否暂停奖励领取功能。
    bool public claimPaused;

    // MetaNode token
    // 奖励代币的合约地址。
    IERC20 public MetaNode;

    // Total pool weight / Sum of all pool weights
    // 所有质押池的权重总和。
    // 每个池有自己的 poolWeight，决定该池分配奖励的比例。
    // totalPoolWeight 是所有池权重的累加值，用于计算每个池实际能分到多少奖励。
    uint256 public totalPoolWeight;
    // 质押池的数组。
    // 每个元素是一个 Pool 结构体，记录一个质押池的所有参数（如质押币种、权重、累计奖励、总质押量等）。
    // 支持多池，方便项目方灵活扩展不同类型的质押池。
    Pool[] public pool;

    // pool id => user address => user info
    // 用于记录每个用户在每个质押池中的详细质押信息。
    // 外层 uint256：表示池子的编号（池 ID，通常是 pool 数组的下标）。
    // 内层 address：表示用户的钱包地址。
    // User：是一个结构体，记录该用户在该池的所有质押相关状态（本金、奖励、解押请求等）。
    // 你可以通过 user[池ID][用户地址] 快速查到某个用户在某个池的所有质押和奖励信息。 支持多池多用户独立管理，互不影响。
    mapping (uint256 => mapping (address => User)) public user;

    // ************************************** EVENT **************************************

    event SetMetaNode(IERC20 indexed MetaNode);

    event PauseWithdraw();

    event UnpauseWithdraw();

    event PauseClaim();

    event UnpauseClaim();

    event SetStartBlock(uint256 indexed startBlock);

    event SetEndBlock(uint256 indexed endBlock);

    event SetMetaNodePerBlock(uint256 indexed MetaNodePerBlock);

    event AddPool(
        address indexed stTokenAddress,
        uint256 indexed poolWeight,
        uint256 indexed lastRewardBlock,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks
    );

    event UpdatePoolInfo(
        uint256 indexed poolId,
        uint256 indexed minDepositAmount,
        uint256 indexed unstakeLockedBlocks
    );

    event SetPoolWeight(
        uint256 indexed poolId,
        uint256 indexed poolWeight,
        uint256 totalPoolWeight
    );

    event UpdatePool(
        uint256 indexed poolId,
        uint256 indexed lastRewardBlock,
        uint256 totalMetaNode
    );

    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);

    event RequestUnstake(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 indexed blockNumber
    );

    event Claim(
        address indexed user,
        uint256 indexed poolId,
        uint256 MetaNodeReward
    );

    // ************************************** MODIFIER **************************************
    // Check if the pool id is valid
    // _pid 是池子的编号（数组下标），如果传入的 _pid 大于等于 pool.length，就会越界，导致访问不存在的池，合约会报错甚至出现安全漏洞。
    modifier checkPid(uint256 _pid) {
        require(_pid < pool.length, "invalid pid");
        _;
    }
    // Check if the pool is ETH pool
    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim is paused");
        _;
    }
    // Check if the pool is ETH pool
    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "withdraw is paused");
        _;
    }

    /**
     * @notice Set MetaNode token address. Set basic info when deploying.
     */
     // Initialize function (replaces constructor for upgradeable contracts)
    function initialize(
        IERC20 _MetaNode,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _MetaNodePerBlock
    ) public initializer {
        // 
        require(_startBlock <= _endBlock && _MetaNodePerBlock > 0, "invalid parameters");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        setMetaNode(_MetaNode);

        startBlock = _startBlock;
        endBlock = _endBlock;
        MetaNodePerBlock = _MetaNodePerBlock;
    }
    // AccessControlUpgradeable 里已经实现了 onlyRole 修饰符。
    // 它的作用是：只有拥有指定角色（如 UPGRADE_ROLE）的账户才能执行被修饰的方法，否则会自动 revert。
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADE_ROLE)
        override
    {

    }

    // ************************************** ADMIN FUNCTION **************************************

    /**
     * @notice Set MetaNode token address. Can only be called by admin
     */
    // 定义了一个公开的合约方法 setMetaNode，用于设置或更改奖励代币
    // 只有拥有 ADMIN_ROLE 管理员权限的账户才能调用这个方法（onlyRole(ADMIN_ROLE) 修饰符限制权限），普通用户无法操作。
    // 这样可以保证只有项目方或授权管理员才能修改奖励代币，提升合约安全性和管理灵活性。
    function setMetaNode(IERC20 _MetaNode) public onlyRole(ADMIN_ROLE) {
        MetaNode = _MetaNode;

        emit SetMetaNode(MetaNode);
    }

    /**
     * @notice Pause withdraw. Can only be called by admin.
     */
    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "withdraw has been already paused");

        withdrawPaused = true;

        emit PauseWithdraw();
    }

    /**
     * @notice Unpause withdraw. Can only be called by admin.
     */
    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "withdraw has been already unpaused");

        withdrawPaused = false;

        emit UnpauseWithdraw();
    }

    /**
     * @notice Pause claim. Can only be called by admin.
     */
    // 这段代码定义了一个合约的管理员操作方法，用于“暂停奖励领取”功能。
    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "claim has been already paused");

        claimPaused = true;

        emit PauseClaim();
    }

    /**
     * @notice Unpause claim. Can only be called by admin.
     */
    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "claim has been already unpaused");

        claimPaused = false;

        emit UnpauseClaim();
    }

    /**
     * @notice Update staking start block. Can only be called by admin.
     */
    // 这段代码定义了一个合约的管理员操作方法，用于设置或更新质押活动的起始区块号。 
    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        // 要求新的起始区块号必须小于或等于结束区块号，否则操作会被拒绝，防止参数设置错误。
        require(_startBlock <= endBlock, "start block must be smaller than end block");
        // 将合约的 startBlock 状态变量更新为新的起始区块号。
        startBlock = _startBlock;
        // 触发 SetStartBlock 事件，方便前端或区块链浏览器监听到这一状态变化。
        emit SetStartBlock(_startBlock);
    }

    /**
     * @notice Update staking end block. Can only be called by admin.
     */
    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(
            startBlock <= _endBlock,
            "start block must be smaller than end block"
        );

        endBlock = _endBlock;

        emit SetEndBlock(_endBlock);
    }

    /**
     * @notice Update the MetaNode reward amount per block. Can only be called by admin.
     */
    // 管理员可以设置每个区块奖励的 MetaNode 代币数量。
    function setMetaNodePerBlock(uint256 _MetaNodePerBlock) public onlyRole(ADMIN_ROLE) {
        require(_MetaNodePerBlock > 0, "invalid parameter");

        MetaNodePerBlock = _MetaNodePerBlock;

        emit SetMetaNodePerBlock(_MetaNodePerBlock);
    }

    /**
     * @notice Add a new staking to pool. Can only be called by admin
     * DO NOT add the same staking token more than once. MetaNode rewards will be messed up if you do
     */
    // address _stTokenAddress 质押池所用的代币地址。第一个池必须是原生币（如 ETH），所以地址为 address(0x0)；后续池可以是任意 ERC20 代币地址。
    // uint256 _poolWeight 该质押池的权重，决定了该池在总奖励中的占比。权重越高，获得的奖励越多。
    // uint256 _minDepositAmount 用户在该池最小质押金额。可以为 0，表示不限制最小质押。
    // uint256 _unstakeLockedBlocks 用户发起解除质押后，需要等待的区块数，期间无法提取质押资金。必须大于 0。提升安全性
    // bool _withUpdate 是否在添加新池前，先更新所有池的奖励分配状态。true 表示先更新，false 表示不更新。
    function addPool(address _stTokenAddress, uint256 _poolWeight, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks,  bool _withUpdate) public onlyRole(ADMIN_ROLE) {
        // Default the first pool to be ETH pool, so the first pool must be added with stTokenAddress = address(0x0)
        // 如果是第一个池，必须用原生币（ETH），地址为 address(0x0)。
        // 如果不是第一个池，不能再用原生币，必须用 ERC20 代币地址。
        if (pool.length > 0) {
            require(
                _stTokenAddress != address(0x0),
                "invalid staking token address"
            );
        } else {
            require(
                _stTokenAddress == address(0x0),
                "invalid staking token address"
            );
        }
        // allow the min deposit amount equal to 0
        //require(_minDepositAmount > 0, "invalid min deposit amount");
        // 要求解押锁定区块数必须大于 0，防止立即提现。
        require(_unstakeLockedBlocks > 0, "invalid withdraw locked blocks");
        // 当前区块必须小于质押活动结束区块，否则不能再添加池
        require(block.number < endBlock, "Already ended");
        // 如果需要，先更新所有已有池的奖励分配状态，防止新池加入后奖励计算混乱。
        if (_withUpdate) {
            massUpdatePools();
        }
        // 新池的奖励起始区块为当前区块或质押活动起始区块（取较大者）。
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        // 累加所有池的权重，用于后续奖励分配。
        totalPoolWeight = totalPoolWeight + _poolWeight;

        pool.push(
            Pool({
                stTokenAddress: _stTokenAddress,
                poolWeight: _poolWeight,
                lastRewardBlock: lastRewardBlock,
                accMetaNodePerST: 0,
                stTokenAmount: 0,
                minDepositAmount: _minDepositAmount,
                unstakeLockedBlocks: _unstakeLockedBlocks
            })
        );

        emit AddPool(
            _stTokenAddress,
            _poolWeight,
            lastRewardBlock,
            _minDepositAmount,
            _unstakeLockedBlocks
        );
    }

    /**
     * @notice Update the given pool's info (minDepositAmount and unstakeLockedBlocks). Can only be called by admin.
     */
    // 更新某个质押池参数的方法
    // _pid：要更新的池子的编号（池 ID）。
    // _minDepositAmount：新的最小质押金额。
    // _unstakeLockedBlocks：新的解押锁定区块数。
    // 只有拥有 ADMIN_ROLE 管理员权限的账户才能调用这个方法（onlyRole(ADMIN_ROLE) 修饰符限制权限），普通用户无法操作。
    // 这样可以保证只有项目方或授权管理员才能修改质押池参数，
    function updatePool(uint256 _pid, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        // 更新指定池的最小质押金额，影响用户后续质押时的门槛。
        pool[_pid].minDepositAmount = _minDepositAmount;
        // 更新指定池的解押锁定区块数，影响用户解押后需要等待多长时间才能提现。
        pool[_pid].unstakeLockedBlocks = _unstakeLockedBlocks;
        // 触发事件，方便前端或区块链浏览器监听到池参数的变化，便于展示和追踪。
        emit UpdatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks);
    }

    /**
     * @notice Update the given pool's weight. Can only be called by admin.
     */
    // 管理员用于修改某个质押池权重的方法,此方法让管理员可以灵活调整某个池的奖励分配比例，影响该池未来能分到多少奖励，并保证所有相关状态和事件同步更新。
    function setPoolWeight(uint256 _pid, uint256 _poolWeight, bool _withUpdate) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        // 要求新的池权重必须大于 0，防止设置为无效或负值。
        require(_poolWeight > 0, "invalid pool weight");
        // 如果 _withUpdate 为 true，则在修改权重前，先更新所有池的奖励分配状态，保证奖励计算准确。
        if (_withUpdate) {
            massUpdatePools();
        }
        // 先从总权重中减去原来的池权重，再加上新的池权重，更新所有池的总权重。
        totalPoolWeight = totalPoolWeight - pool[_pid].poolWeight + _poolWeight;
        // 把指定池的权重更新为新的值。
        pool[_pid].poolWeight = _poolWeight;
        // 触发事件，通知前端或区块链浏览器该池权重已被修改，便于追踪和展示。
        emit SetPoolWeight(_pid, _poolWeight, totalPoolWeight);
    }

    // ************************************** QUERY FUNCTION **************************************

    /**
     * @notice Get the length/amount of pool
     */
    function poolLength() external view returns (uint256) {
        return pool.length;
    }

    /**
     * @notice Return reward multiplier over given _from to _to block. [_from, _to)
     *
     * @param _from    From block number (included)
     * @param _to      To block number (exluded)
     * getMultiplier(pool_.lastRewardBlock, block.number).tryMul(pool_.poolWeight);
     */
    // 用来计算某个区块区间内应发放的奖励总量
    // 此函数用于奖励分配逻辑，确保只在有效区块范围内计算奖励，并防止溢出，是奖励精确、安全发放的关键辅助函数。
    function getMultiplier(uint256 _from, uint256 _to) public view returns(uint256 multiplier) {
        // 检查起始区块 _from 必须小于等于结束区块 _to，否则报错
        require(_from <= _to, "invalid block");
        // 如果 _from 小于质押活动的起始区块，则用 startBlock 替代，保证计算区间在有效范围内。
        if (_from < startBlock) {_from = startBlock;}
        // 如果 _to 大于质押活动的结束区块，则用 endBlock 替代，保证计算区间不超出活动范围。
        if (_to > endBlock) {_to = endBlock;}
        // 再次校验调整后的区块区间是否合法。
        require(_from <= _to, "end block must be greater than start block");
        bool success;
        // 计算区块区间长度 (_to - _from)，再乘以每区块奖励 MetaNodePerBlock，得到总奖励数量
        // 用 tryMul 防止溢出，如果溢出则报错。
        // 返回 multiplier，即该区间应发放的奖励总量。
        (success, multiplier) = (_to - _from).tryMul(MetaNodePerBlock);
        require(success, "multiplier overflow");
    }

    /**
     * @notice Get pending MetaNode amount of user in pool
     */
    function pendingMetaNode(
        uint256 _pid,
        address _user
    ) external view checkPid(_pid) returns (uint256) {
        return pendingMetaNodeByBlockNumber(_pid, _user, block.number);
    }

    /**
     * @notice Get pending MetaNode amount of user by block number in pool
     */
    // 计算某个用户在指定区块高度时，在某个质押池中可领取的奖励（MetaNode 代币）数量。
    function pendingMetaNodeByBlockNumber(uint256 _pid, address _user, uint256 _blockNumber) public checkPid(_pid) view returns(uint256) {
        // 取出指定池（_pid）和用户（_user）的质押信息。       
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][_user];
        // accMetaNodePerST 是当前池每个质押代币累计获得的奖励。
        uint256 accMetaNodePerST = pool_.accMetaNodePerST;
        // stSupply 是当前池的总质押量。
        uint256 stSupply = pool_.stTokenAmount;
        // 如果查询的区块号大于上次奖励分配区块，并且池中有质押：
        if (_blockNumber > pool_.lastRewardBlock && stSupply != 0) {
            // 计算从上次分配到 _blockNumber 之间，这个池应获得的总奖励（MetaNodeForPool）。getMultiplier 计算区块区间内的总奖励数量。
            uint256 multiplier = getMultiplier(pool_.lastRewardBlock, _blockNumber);
            // 按池权重分配奖励。
            uint256 MetaNodeForPool = multiplier * pool_.poolWeight / totalPoolWeight;
            // 更新 accMetaNodePerST，即把新奖励按总质押量分摊到每个质押代币上。
            // MetaNodeForPool * (1 ether) / stSupply：表示每 1 个质押代币本次能分到多少奖励（放大 1e18 倍）。
            accMetaNodePerST = accMetaNodePerST + MetaNodeForPool * (1 ether) / stSupply;
        }
        // 计算该用户在该池的总应得奖励
        // 用户当前质押量 × 每个质押代币累计奖励（注意精度缩放）。
        // 减去用户已领取的奖励（finishedMetaNode）。
        // 加上之前未领取的奖励（pendingMetaNode）。
        // 当你要计算用户实际应得奖励时，需要把这个放大的数值“还原”回来，所以要除以 1 ether。
        return user_.stAmount * accMetaNodePerST / (1 ether) - user_.finishedMetaNode + user_.pendingMetaNode;
    }

    /**
     * @notice Get the staking amount of user
     */
    function stakingBalance(
        uint256 _pid,
        address _user
    ) external view checkPid(_pid) returns (uint256) {
        return user[_pid][_user].stAmount;
    }

    /**
     * @notice Get the withdraw amount info, including the locked unstake amount and the unlocked unstake amount
     */
    // 查询某个用户在某个池的所有解押请求中，已解锁（可提现）和总共请求的解押金额。
    function withdrawAmount(uint256 _pid, address _user) public checkPid(_pid) view returns(uint256 requestAmount, uint256 pendingWithdrawAmount) {
        User storage user_ = user[_pid][_user];

        for (uint256 i = 0; i < user_.requests.length; i++) {
            // 如果某个请求的 unlockBlocks 小于等于当前区块号，说明这笔解押已经到了解锁时间
            // 可以提现，于是把它的金额加到 pendingWithdrawAmount。
            if (user_.requests[i].unlockBlocks <= block.number) {
                pendingWithdrawAmount =
                    pendingWithdrawAmount +
                    user_.requests[i].amount;
            }
            // 无论是否已解锁，都把该请求的金额加到 requestAmount，表示用户总共请求了解押多少金额。
            requestAmount = requestAmount + user_.requests[i].amount;
        }
    }

    // ************************************** PUBLIC FUNCTION **************************************

    /**
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    // 此函数会把某个池的奖励分配状态更新到最新区块，确保奖励分配公平、精确，并防止溢出等安全问题。
    function updatePool(uint256 _pid) public checkPid(_pid) {
        Pool storage pool_ = pool[_pid];
        // 如果当前区块号小于等于上次奖励分配区块号，说明奖励已经是最新的，无需更新，直接返回。
        if (block.number <= pool_.lastRewardBlock) {
            return;
        }
         // 计算从上次分配到当前区块之间，这个池应获得的总奖励（未按总权重分配前）。
         // 用 tryMul 防止溢出，success1 为 false 时会报错。
         // getMultiplier(pool_.lastRewardBlock, block.number) 计算区块区间内的总奖励数量。
         // 再乘以该池的权重 pool_.poolWeight，得到该池应获得的奖励总量（未按总权重分配前）。
        (bool success1, uint256 totalMetaNode) = getMultiplier(pool_.lastRewardBlock, block.number).tryMul(pool_.poolWeight);
        require(success1, "overflow");
        // 按所有池的总权重分配奖励，得到该池实际应获得的奖励。
        (success1, totalMetaNode) = totalMetaNode.tryDiv(totalPoolWeight);
        require(success1, "overflow");
        // 用 tryDiv 防止溢出。
        // 获取当前池的总质押量 stSupply。
        uint256 stSupply = pool_.stTokenAmount;
        // 如果池中有质押，才需要分配奖励。
        if (stSupply > 0) {
            // 把奖励总量放大 1e18（1 ether），用于精度控制。
            (bool success2, uint256 totalMetaNode_) = totalMetaNode.tryMul(1 ether);
            require(success2, "overflow");
            // 再除以总质押量，得到每 1 个质押代币本次能分到多少奖励（精度放大 1e18）。
            (success2, totalMetaNode_) = totalMetaNode_.tryDiv(stSupply);
            require(success2, "overflow");
            // 把本次每个质押代币能分到的奖励累加到池的累计奖励（accMetaNodePerST）上。
            // 用 tryAdd 防止溢出。
            (bool success3, uint256 accMetaNodePerST) = pool_.accMetaNodePerST.tryAdd(totalMetaNode_);
            require(success3, "overflow");
            pool_.accMetaNodePerST = accMetaNodePerST;
        }
        // 更新池的上次奖励分配区块号为当前区块。
        pool_.lastRewardBlock = block.number;
        // 触发事件，通知前端或区块链浏览器该池奖励已更新，便于追踪和展示。
        emit UpdatePool(_pid, pool_.lastRewardBlock, totalMetaNode);
    }

    /**
     * @notice Update reward variables for all pools. Be careful of gas spending!
     */
    function massUpdatePools() public {
        uint256 length = pool.length;
        for (uint256 pid = 0; pid < length; pid++) {
            updatePool(pid);
        }
    }

    /**
     * @notice Deposit staking ETH for MetaNode rewards
     */
    // whenNotPaused() 修饰符保证合约未被暂停。payable 允许用户发送 ETH 到合约。
    // 让用户可以直接用 ETH 参与质押，合约会校验池类型和金额，并自动完成质押和奖励分配相关操作。
    function depositETH() public whenNotPaused() payable {
        // 获取第一个池（ETH 池）的配置信息。
        Pool storage pool_ = pool[ETH_PID];
        // 检查该池确实是原生币池（地址为 address(0x0)），防止误用。
        require(pool_.stTokenAddress == address(0x0), "invalid staking token address");
        // 获取用户本次发送的 ETH 数量。
        uint256 _amount = msg.value;
        // 检查质押金额是否大于等于池的最小质押要求。
        require(_amount >= pool_.minDepositAmount, "deposit amount is too small");
        // 调用内部 _deposit 方法，完成质押逻辑（如更新用户余额、奖励等）。
        _deposit(ETH_PID, _amount);
    }

    /**
     * @notice Deposit staking token for MetaNode rewards
     * Before depositing, user needs approve this contract to be able to spend or transfer their staking tokens
     *
     * @param _pid       Id of the pool to be deposited to
     * @param _amount    Amount of staking tokens to be deposited
     */
    function deposit(
        uint256 _pid,
        uint256 _amount
    ) public whenNotPaused checkPid(_pid) {
        require(_pid != 0, "deposit not support ETH staking");
        Pool storage pool_ = pool[_pid];
        require(
            _amount > pool_.minDepositAmount,
            "deposit amount is too small"
        );

        if(_amount > 0) {
            // 把用户的质押代币从用户地址转到合约地址。
            IERC20(pool_.stTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        }

        _deposit(_pid, _amount);
    }

    /**
     * @notice Unstake staking tokens
     *
     * @param _pid       Id of the pool to be withdrawn from
     * @param _amount    amount of staking tokens to be withdrawn
     */
     // 用户发起解除质押请求的方法
     // 用户调用此方法时，合约会检查用户是否有足够的质押余额，并更新奖励状态，然后把用户请求的解押金额和解锁区块号记录下来，等待用户后续提现。
     // whenNotPaused() 修饰符保证合约未被暂停。
    function unstake(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        require(user_.stAmount >= _amount, "Not enough staking token balance");

        updatePool(_pid);
        // 计算用户在当前池中未领取的 MetaNode 奖励。   
        // 用户质押量乘以每个质押代币累计奖励，除以 1 ether（精度缩放），减去已领取奖励，得到当前应得但未领取的奖励。
        // 把这部分奖励累加到用户的 pendingMetaNode 中，等待用户后续领取。
        // 这样做可以确保用户在解除质押时不会丢失任何应得奖励。    
        uint256 pendingMetaNode_ = user_.stAmount * pool_.accMetaNodePerST / (1 ether) - user_.finishedMetaNode;

        if (pendingMetaNode_ > 0) {
            user_.pendingMetaNode = user_.pendingMetaNode + pendingMetaNode_;
        }

        if(_amount > 0) {
            // 减少用户的质押余额。
            user_.stAmount = user_.stAmount - _amount;
            user_.requests.push(UnstakeRequest({
                amount: _amount,
                // 记录解锁区块号
                // 用户发起解押请求后，需要等待一定数量的区块（pool_.unstakeLockedBlocks）才能真正提现。
                unlockBlocks: block.number + pool_.unstakeLockedBlocks
            }));
        }
        // 减少池的总质押量。
        pool_.stTokenAmount = pool_.stTokenAmount - _amount;
        // 更新用户已领取奖励为当前质押量对应的累计奖励，防止重复计算。
        user_.finishedMetaNode = user_.stAmount * pool_.accMetaNodePerST / (1 ether);

        emit RequestUnstake(msg.sender, _pid, _amount);
    }

    /**
     * @notice Withdraw the unlock unstake amount
     *
     * @param _pid       Id of the pool to be withdrawn from
     */
    function withdraw(
        uint256 _pid
    ) public whenNotPaused checkPid(_pid) whenNotWithdrawPaused {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        uint256 pendingWithdraw_;
        uint256 popNum_;
        // 计算并累计所有已解锁的解押请求金额
        for (uint256 i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocks > block.number) {
                break;
            }
            pendingWithdraw_ = pendingWithdraw_ + user_.requests[i].amount;
            popNum_++;
        }
        // 先将已解锁的请求移到数组前面
        for (uint256 i = 0; i < user_.requests.length - popNum_; i++) {
            user_.requests[i] = user_.requests[i + popNum_];
        }
        // 移除已解锁的请求
        for (uint256 i = 0; i < popNum_; i++) {
            user_.requests.pop();
        }

        if (pendingWithdraw_ > 0) {
            // 将已解锁的质押金额转给用户
            // 判断当前池的质押代币是不是原生币（如 ETH）
            if (pool_.stTokenAddress == address(0x0)) {
                _safeETHTransfer(msg.sender, pendingWithdraw_);
            } else {
                IERC20(pool_.stTokenAddress).safeTransfer(
                    msg.sender,
                    pendingWithdraw_
                );
            }
        }

        emit Withdraw(msg.sender, _pid, pendingWithdraw_, block.number);
    }

    /**
     * @notice Claim MetaNode tokens reward
     *
     * @param _pid       Id of the pool to be claimed from
     */
    function claim(
        uint256 _pid
    ) public whenNotPaused checkPid(_pid) whenNotClaimPaused {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        updatePool(_pid);

        uint256 pendingMetaNode_ = (user_.stAmount * pool_.accMetaNodePerST) /
            (1 ether) -
            user_.finishedMetaNode +
            user_.pendingMetaNode;

        if (pendingMetaNode_ > 0) {
            user_.pendingMetaNode = 0;
            _safeMetaNodeTransfer(msg.sender, pendingMetaNode_);
        }

        user_.finishedMetaNode =
            (user_.stAmount * pool_.accMetaNodePerST) /
            (1 ether);

        emit Claim(msg.sender, _pid, pendingMetaNode_);
    }

    // ************************************** INTERNAL FUNCTION **************************************

    /**
     * @notice Deposit staking token for MetaNode rewards
     *
     * @param _pid       Id of the pool to be deposited to
     * @param _amount    Amount of staking tokens to be deposited
     */

    // 内部质押逻辑函数，更新用户和池的质押及奖励状态  
    function _deposit(uint256 _pid, uint256 _amount) internal {
        // 取出指定池和用户的质押信息。
        Pool storage pool_ = pool[_pid];
        // 获取用户的质押信息。
        User storage user_ = user[_pid][msg.sender];
        // 更新池的奖励分配状态到最新区块。
        updatePool(_pid);
        // 计算用户当前应得但未领取的奖励。
        if (user_.stAmount > 0) {
            // uint256 accST = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
            // 用 tryMul 和 tryDiv 防止溢出。
            // 计算用户质押量乘以每个质押代币累计奖励
            (bool success1, uint256 accST) = user_.stAmount.tryMul(pool_.accMetaNodePerST);
            require(success1, "user stAmount mul accMetaNodePerST overflow");
            // 再除以总质押量，得到每 1 个质押代币本次能分到多少奖励（精度放大 1e18）。
            // 为什么精度要放大 1e18？因为 accMetaNodePerST 在更新时是乘以了 1 ether 的。
            (success1, accST) = accST.tryDiv(1 ether);
            require(success1, "accST div 1 ether overflow");
            // 计算用户当前应得但未领取的奖励 = 累计奖励 - 已领取奖励
            // accST 是用户质押量乘以每个质押代币累计奖励后的值（精度放大 1e18）。
            // user_.finishedMetaNode 是用户已领取的奖励。
            // 两者相减得到用户当前应得但未领取的奖励。
            (bool success2, uint256 pendingMetaNode_) = accST.trySub(user_.finishedMetaNode);
            require(success2, "accST sub finishedMetaNode overflow");

            if(pendingMetaNode_ > 0) {
                // 把当前应得但未领取的奖励，累加到用户的待领取奖励中。
                (bool success3, uint256 _pendingMetaNode) = user_.pendingMetaNode.tryAdd(pendingMetaNode_);
                require(success3, "user pendingMetaNode overflow");
                // 更新用户当前应得但未领取的奖励
                user_.pendingMetaNode = _pendingMetaNode;
            }
        }

        if(_amount > 0) {
            // 把用户本次质押金额，累加到用户的质押余额中。
            (bool success4, uint256 stAmount) = user_.stAmount.tryAdd(_amount);
            require(success4, "user stAmount overflow");
            // 更新用户的质押余额
            user_.stAmount = stAmount;
        }
        // 把用户本次质押金额，累加到池的总质押量中。
        // 更新池的总质押量
        (bool success5, uint256 stTokenAmount) = pool_.stTokenAmount.tryAdd(_amount);
        require(success5, "pool stTokenAmount overflow");
        pool_.stTokenAmount = stTokenAmount;
        // 更新用户已领取奖励 = 用户质押余额 × 每个质押代币累计奖励
        // 这里为什么是已领取奖励？因为上面已经把当前应得但未领取的奖励，累加到用户的待领取奖励中去了。
        // 所以这里更新已领取奖励时，只需计算用户当前质押余额对应
        // user_.finishedMetaNode = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
        (bool success6, uint256 finishedMetaNode) = user_.stAmount.tryMul(
            pool_.accMetaNodePerST
        );
        require(success6, "user stAmount mul accMetaNodePerST overflow");

        (success6, finishedMetaNode) = finishedMetaNode.tryDiv(1 ether);
        require(success6, "finishedMetaNode div 1 ether overflow");
     
        user_.finishedMetaNode = finishedMetaNode;

        emit Deposit(msg.sender, _pid, _amount);
    }

    /**
     * @notice Safe MetaNode transfer function, just in case if rounding error causes pool to not have enough MetaNodes
     *
     * @param _to        Address to get transferred MetaNodes
     * @param _amount    Amount of MetaNode to be transferred
     */
    // 安全转账奖励代币（MetaNode）的内部函数，用于防止因精度误差或奖励计算问题导致合约余额不足时转账失败。 
    function _safeMetaNodeTransfer(address _to, uint256 _amount) internal {
        // 查询当前合约地址持有的 MetaNode 代币余额。
        uint256 MetaNodeBal = MetaNode.balanceOf(address(this));
        // 如果要转账的数量 _amount 大于合约实际余额，只转出合约剩余的全部余额，防止转账失败。
        if (_amount > MetaNodeBal) {
            MetaNode.transfer(_to, MetaNodeBal);
        } else {
            // 如果余额充足，则正常转账指定数量。
            MetaNode.transfer(_to, _amount);
        }
    }

    /**
     * @notice Safe ETH transfer function
     *
     * @param _to        Address to get transferred ETH
     * @param _amount    Amount of ETH to be transferred
     */
    // 这段代码是一个安全转账 ETH 的内部函数，用于将 ETH 从合约发送到指定地址 _to，并确保转账成功。 
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        // 这里用的是 address(_to).call{value: _amount}("")，这是 Solidity 推荐的发送 ETH 的安全方法。
        // 这样做可以避免 transfer 和 send 的 gas 限制问题，兼容所有类型的接收方（包括合约和普通地址）。
        // call 返回两个值：success 表示转账是否成功，data 是对方合约返回的数据（如果有）。
        (bool success, bytes memory data) = address(_to).call{
            value: _amount
        }("");
        // 如果转账失败（success == false），则直接 revert，防止资金丢失。
        require(success, "ETH transfer call failed");
        // 如果 data 长度大于 0，说明接收方是一个合约，并且返回了数据。
        if (data.length > 0) {
            require(
                // abi.decode(data, (bool)) 会把返回的数据解码为布尔值（true 或 false）。
                // 如果解码结果不是 true，则说明对方合约主动返回了失败，转账同样会 revert。
                // 在 Solidity 里，data 是一个 bytes 类型的二进制数据，代表被调用方合约返回的原始数据。
                abi.decode(data, (bool)),
                "ETH transfer operation did not succeed"
            );
        }
    }
}
