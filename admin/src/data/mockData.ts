// Mock data for the entire e-commerce admin system

export const mockStats = {
  totalRevenue: 1284560,
  revenueGrowth: 12.5,
  totalOrders: 8432,
  ordersGrowth: 8.3,
  totalUsers: 32891,
  usersGrowth: 5.2,
  totalProducts: 1256,
  productsGrowth: 2.1,
};

export const mockRevenueData = [
  { month: "1月", revenue: 82000, orders: 620 },
  { month: "2月", revenue: 74000, orders: 580 },
  { month: "3月", revenue: 95000, orders: 740 },
  { month: "4月", revenue: 110000, orders: 860 },
  { month: "5月", revenue: 98000, orders: 770 },
  { month: "6月", revenue: 125000, orders: 950 },
  { month: "7月", revenue: 142000, orders: 1120 },
  { month: "8月", revenue: 138000, orders: 1080 },
  { month: "9月", revenue: 160000, orders: 1240 },
  { month: "10月", revenue: 175000, orders: 1380 },
  { month: "11月", revenue: 198000, orders: 1560 },
  { month: "12月", revenue: 220000, orders: 1720 },
];

export const mockCategoryData = [
  { name: "服装配饰", value: 32, color: "#f48fb1" },
  { name: "数码电器", value: 25, color: "#ce93d8" },
  { name: "美妆护肤", value: 18, color: "#90caf9" },
  { name: "家居生活", value: 12, color: "#a5d6a7" },
  { name: "运动户外", value: 8, color: "#ffcc80" },
  { name: "其他", value: 5, color: "#c5cae9" },
];

export const mockWeeklyData = [
  { day: "周一", visits: 4200, sales: 1800 },
  { day: "周二", visits: 3800, sales: 2100 },
  { day: "周三", visits: 5100, sales: 2400 },
  { day: "周四", visits: 4700, sales: 2200 },
  { day: "周五", visits: 6200, sales: 3100 },
  { day: "周六", visits: 7800, sales: 4200 },
  { day: "周日", visits: 7200, sales: 3800 },
];

export const mockConversionData = [
  { name: "访问量", value: 100 },
  { name: "加购率", value: 42 },
  { name: "下单率", value: 28 },
  { name: "支付率", value: 22 },
];

interface MockProduct {
  id: string;
  name: string;
  category: string;
  price: number;
  stock: number;
  sales: number;
  status: "on" | "off";
  image: string;
  rating: number;
}

export const mockProducts: MockProduct[] = [
  {
    id: "P001",
    name: "经典马卡龙蕾丝连衣裙",
    category: "服装配饰",
    price: 299,
    stock: 128,
    sales: 342,
    status: "on",
    image: "👗",
    rating: 4.8,
  },
  {
    id: "P002",
    name: "无线降噪蓝牙耳机Pro",
    category: "数码电器",
    price: 899,
    stock: 56,
    sales: 218,
    status: "on",
    image: "🎧",
    rating: 4.9,
  },
  {
    id: "P003",
    name: "玫瑰精华保湿面霜",
    category: "美妆护肤",
    price: 168,
    stock: 0,
    sales: 567,
    status: "off",
    image: "🧴",
    rating: 4.7,
  },
  {
    id: "P004",
    name: "北欧风格陶瓷花瓶",
    category: "家居生活",
    price: 128,
    stock: 89,
    sales: 134,
    status: "on",
    image: "🏺",
    rating: 4.6,
  },
  {
    id: "P005",
    name: "专业瑜伽垫加厚防滑",
    category: "运动户外",
    price: 199,
    stock: 203,
    sales: 289,
    status: "on",
    image: "🧘",
    rating: 4.8,
  },
  {
    id: "P006",
    name: "粉色小熊保温杯500ml",
    category: "家居生活",
    price: 89,
    stock: 15,
    sales: 892,
    status: "on",
    image: "🧋",
    rating: 4.9,
  },
  {
    id: "P007",
    name: "樱花限定香水礼盒套装",
    category: "美妆护肤",
    price: 458,
    stock: 42,
    sales: 156,
    status: "on",
    image: "🌸",
    rating: 4.7,
  },
  {
    id: "P008",
    name: "复古皮质双肩包",
    category: "服装配饰",
    price: 349,
    stock: 0,
    sales: 278,
    status: "off",
    image: "🎒",
    rating: 4.5,
  },
];

export const mockOrders = [
  {
    id: "ORD20241201",
    user: "小糖豆",
    avatar: "🐱",
    products: "经典马卡龙蕾丝连衣裙 x1",
    amount: 299,
    status: "delivered",
    date: "2024-12-01",
    address: "上海市浦东新区陆家嘴街道",
  },
  {
    id: "ORD20241202",
    user: "晴天云朵",
    avatar: "🐰",
    products: "无线降噪蓝牙耳机Pro x1",
    amount: 899,
    status: "shipping",
    date: "2024-12-02",
    address: "北京市朝阳区三里屯街道",
  },
  {
    id: "ORD20241203",
    user: "奶油泡芙",
    avatar: "🐻",
    products: "粉色小熊保温杯500ml x2",
    amount: 178,
    status: "pending",
    date: "2024-12-03",
    address: "广州市天河区珠江新城",
  },
  {
    id: "ORD20241204",
    user: "蜜桃少女",
    avatar: "🌷",
    products: "樱花限定香水礼盒套装 x1",
    amount: 458,
    status: "delivered",
    date: "2024-12-04",
    address: "深圳市南山区科技园",
  },
  {
    id: "ORD20241205",
    user: "棉花糖云",
    avatar: "🐼",
    products: "专业瑜伽垫加厚防滑 x1",
    amount: 199,
    status: "cancelled",
    date: "2024-12-05",
    address: "成都市武侯区锦里",
  },
  {
    id: "ORD20241206",
    user: "柠檬小鹿",
    avatar: "🦌",
    products: "北欧风格陶瓷花瓶 x2",
    amount: 256,
    status: "shipping",
    date: "2024-12-06",
    address: "杭州市西湖区文化广场",
  },
  {
    id: "ORD20241207",
    user: "泡泡糖糖",
    avatar: "🐨",
    products: "玫瑰精华保湿面霜 x3",
    amount: 504,
    status: "pending",
    date: "2024-12-07",
    address: "武汉市江汉区解放大道",
  },
  {
    id: "ORD20241208",
    user: "草莓冰冰",
    avatar: "🍓",
    products: "经典马卡龙蕾丝连衣裙 x1, 粉色小熊保温杯 x1",
    amount: 388,
    status: "delivered",
    date: "2024-12-08",
    address: "西安市碑林区南大街",
  },
];

export const mockUsers = [
  {
    id: "U001",
    name: "小糖豆",
    avatar: "🐱",
    email: "xiaotangdou@mail.com",
    phone: "138****8801",
    level: "VIP3",
    orders: 42,
    totalSpend: 12800,
    joinDate: "2022-03-15",
    status: "active",
  },
  {
    id: "U002",
    name: "晴天云朵",
    avatar: "🐰",
    email: "qingtianyunduo@mail.com",
    phone: "139****9902",
    level: "VIP1",
    orders: 12,
    totalSpend: 3600,
    joinDate: "2023-06-20",
    status: "active",
  },
  {
    id: "U003",
    name: "奶油泡芙",
    avatar: "🐻",
    email: "naiyoupaofu@mail.com",
    phone: "136****6603",
    level: "VIP2",
    orders: 28,
    totalSpend: 8900,
    joinDate: "2022-11-08",
    status: "active",
  },
  {
    id: "U004",
    name: "蜜桃少女",
    avatar: "🌷",
    email: "mitaoshaonu@mail.com",
    phone: "137****7704",
    level: "VIP5",
    orders: 156,
    totalSpend: 58600,
    joinDate: "2021-05-12",
    status: "active",
  },
  {
    id: "U005",
    name: "棉花糖云",
    avatar: "🐼",
    email: "mianhuatangyun@mail.com",
    phone: "132****2205",
    level: "VIP1",
    orders: 5,
    totalSpend: 1200,
    joinDate: "2024-01-30",
    status: "inactive",
  },
  {
    id: "U006",
    name: "柠檬小鹿",
    avatar: "🦌",
    email: "ningmengxiaolu@mail.com",
    phone: "155****5506",
    level: "VIP2",
    orders: 19,
    totalSpend: 6700,
    joinDate: "2023-02-14",
    status: "active",
  },
];

export const mockNotifications = [
  { id: 1, type: "order", message: "新订单 #ORD20241208 待处理", time: "2分钟前", read: false },
  { id: 2, type: "stock", message: "商品「粉色小熊保温杯」库存不足，仅剩15件", time: "1小时前", read: false },
  { id: 3, type: "user", message: "新用户注册：草莓冰冰", time: "3小时前", read: true },
  { id: 4, type: "order", message: "订单 #ORD20241205 已取消，需处理退款", time: "5小时前", read: true },
];

export const currentAdmin = {
  name: "管理员 Luna",
  role: "超级管理员",
  avatar: "👩‍💼",
  email: "admin@macaronshop.com",
};
