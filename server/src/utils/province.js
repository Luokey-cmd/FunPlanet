/** 用于从收货地址中识别省份，并映射到地图用标准名称 */
const PROVINCE_ALIASES = [
  { name: '北京市', keys: ['北京'] },
  { name: '天津市', keys: ['天津'] },
  { name: '上海市', keys: ['上海'] },
  { name: '重庆市', keys: ['重庆'] },
  { name: '河北省', keys: ['河北'] },
  { name: '山西省', keys: ['山西'] },
  { name: '辽宁省', keys: ['辽宁'] },
  { name: '吉林省', keys: ['吉林'] },
  { name: '黑龙江省', keys: ['黑龙江'] },
  { name: '江苏省', keys: ['江苏'] },
  { name: '浙江省', keys: ['浙江'] },
  { name: '安徽省', keys: ['安徽'] },
  { name: '福建省', keys: ['福建'] },
  { name: '江西省', keys: ['江西'] },
  { name: '山东省', keys: ['山东'] },
  { name: '河南省', keys: ['河南'] },
  { name: '湖北省', keys: ['湖北'] },
  { name: '湖南省', keys: ['湖南'] },
  { name: '广东省', keys: ['广东'] },
  { name: '海南省', keys: ['海南'] },
  { name: '四川省', keys: ['四川'] },
  { name: '贵州省', keys: ['贵州'] },
  { name: '云南省', keys: ['云南'] },
  { name: '陕西省', keys: ['陕西'] },
  { name: '甘肃省', keys: ['甘肃'] },
  { name: '青海省', keys: ['青海'] },
  { name: '台湾省', keys: ['台湾'] },
  { name: '内蒙古自治区', keys: ['内蒙古'] },
  { name: '广西壮族自治区', keys: ['广西'] },
  { name: '西藏自治区', keys: ['西藏'] },
  { name: '宁夏回族自治区', keys: ['宁夏'] },
  { name: '新疆维吾尔自治区', keys: ['新疆'] },
  { name: '香港特别行政区', keys: ['香港'] },
  { name: '澳门特别行政区', keys: ['澳门'] },
];

export function parseProvinceFromAddress(address) {
  const text = String(address ?? '').trim();
  if (!text) return null;
  for (const item of PROVINCE_ALIASES) {
    if (item.keys.some((key) => text.includes(key))) return item.name;
  }
  return null;
}

export function aggregateProvinceHeat(orders) {
  const map = new Map();
  for (const order of orders) {
    const province = parseProvinceFromAddress(order.addressDetail);
    if (!province) continue;
    map.set(province, (map.get(province) ?? 0) + 1);
  }
  return [...map.entries()]
    .map(([name, value]) => ({ name, value }))
    .sort((a, b) => b.value - a.value);
}
