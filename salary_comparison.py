#!/usr/bin/env python3
"""
Salary Comparison Script
Compares real NFL team salary data with PFL generated salaries
"""

import csv
from collections import defaultdict
import locale

def compare_salaries():
    """Compare real NFL salaries with PFL generated salaries"""
    
    # Set locale for proper number formatting
    try:
        locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')
    except:
        pass
    
    # Team name mapping from PFL to NFL abbreviations
    team_mapping = {
        'Cleveland': 'CLE',
        'San Francisco': 'SF', 
        'New York N': 'NYG',
        'Washington': 'WAS',
        'Atlanta': 'ATL',
        'Las Vegas': 'LV',
        'Jacksonville': 'JAX',
        'Houston': 'HOU',
        'Indianapolis': 'IND',
        'Dallas': 'DAL',
        'Buffalo': 'BUF',
        'Miami': 'MIA',
        'Chicago': 'CHI',
        'Kansas City': 'KC',
        'Green Bay': 'GB',
        'Tennessee': 'TEN',
        'Baltimore': 'BAL',
        'Carolina': 'CAR',
        'Los Angeles N': 'LAR',
        'New England': 'NE',
        'New Orleans': 'NO',
        'Philadelphia': 'PHI',
        'Cincinnati': 'CIN',
        'Minnesota': 'MIN',
        'Denver': 'DEN',
        'Arizona': 'ARI',
        'Detroit': 'DET',
        'Tampa Bay': 'TB',
        'Seattle': 'SEA',
        'Pittsburgh': 'PIT',
        'New York A': 'NYJ',
        'Los Angeles A': 'LAC'
    }
    
    # Load real NFL data
    real_nfl_data = {}
    print("🏈 Loading real NFL team salary data...")
    
    try:
        with open('PSF26Tests/TEAM TOTALS - Sheet1.csv', 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                if row['TEAM'] and row['TEAM'] != '':
                    team = row['TEAM']
                    # Convert salary strings to numbers (remove $ and commas)
                    top51_cap = float(row['TOTAL CAPTOP-51'].replace('$', '').replace(',', '')) if row['TOTAL CAPTOP-51'] else 0
                    all_cap = float(row['TOTAL CAPALLOCATIONS'].replace('$', '').replace(',', '')) if row['TOTAL CAPALLOCATIONS'] else 0
                    cap_space = float(row['CAP SPACETOP-51'].replace('$', '').replace(',', '')) if row['CAP SPACETOP-51'] else 0
                    
                    real_nfl_data[team] = {
                        'top51_cap': top51_cap,
                        'all_cap': all_cap,
                        'cap_space': cap_space,
                        'players_active': int(row['PLAYERSACTIVE']) if row['PLAYERSACTIVE'] else 0
                    }
        
        print(f"✅ Loaded {len(real_nfl_data)} NFL teams")
        print(f"Sample NFL data: {list(real_nfl_data.keys())[:5]}")
        
    except Exception as e:
        print(f"❌ Error reading NFL data: {e}")
        return
    
    # Load PFL generated data
    pfl_data = {}
    print("🎮 Loading PFL generated salary data...")
    
    try:
        with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                team = row['Team']
                if team not in pfl_data:
                    pfl_data[team] = {
                        'total_apy': 0,
                        'player_count': 0,
                        'players': []
                    }
                
                if 'contractAPY_M' in row and row['contractAPY_M'] != '':
                    apy = float(row['contractAPY_M'])
                    pfl_data[team]['total_apy'] += apy
                    pfl_data[team]['player_count'] += 1
                    pfl_data[team]['players'].append({
                        'name': f"{row['firstName']} {row['lastName']}",
                        'apy': apy,
                        'overall': row['overallRating']
                    })
        
        print(f"✅ Loaded {len(pfl_data)} PFL teams")
        print(f"Sample PFL data: {list(pfl_data.keys())[:5]}")
        
    except Exception as e:
        print(f"❌ Error reading PFL data: {e}")
        return
    
    # Create comparison using team mapping
    print("\n🔍 SALARY COMPARISON ANALYSIS")
    print("=" * 100)
    
    comparison_data = []
    
    for pfl_team, nfl_abbr in team_mapping.items():
        if pfl_team in pfl_data and nfl_abbr in real_nfl_data:
            real_top51 = real_nfl_data[nfl_abbr]['top51_cap'] / 1_000_000  # Convert to millions
            real_all = real_nfl_data[nfl_abbr]['all_cap'] / 1_000_000
            pfl_apy = pfl_data[pfl_team]['total_apy']
            
            # Calculate discrepancies
            top51_diff = pfl_apy - real_top51
            all_diff = pfl_apy - real_all
            top51_diff_pct = (top51_diff / real_top51) * 100 if real_top51 > 0 else 0
            all_diff_pct = (all_diff / real_all) * 100 if real_all > 0 else 0
            
            comparison_data.append({
                'pfl_team': pfl_team,
                'nfl_abbr': nfl_abbr,
                'real_top51': real_top51,
                'real_all': real_all,
                'pfl_apy': pfl_apy,
                'top51_diff': top51_diff,
                'all_diff': all_diff,
                'top51_diff_pct': top51_diff_pct,
                'all_diff_pct': all_diff_pct
            })
    
    if not comparison_data:
        print("❌ No teams matched between PFL and NFL data!")
        print(f"PFL teams: {list(pfl_data.keys())}")
        print(f"NFL teams: {list(real_nfl_data.keys())}")
        return
    
    # Sort by biggest discrepancies (absolute difference)
    comparison_data.sort(key=lambda x: abs(x['top51_diff']), reverse=True)
    
    print(f"{'PFL TEAM':<20} {'NFL':<4} {'REAL TOP51':<12} {'REAL ALL':<12} {'PFL APY':<12} {'DIFF TOP51':<12} {'DIFF ALL':<12} {'% DIFF':<10}")
    print("-" * 100)
    
    for data in comparison_data:
        print(f"{data['pfl_team']:<20} {data['nfl_abbr']:<4} ${data['real_top51']:<11.1f}M ${data['real_all']:<11.1f}M ${data['pfl_apy']:<11.1f}M "
              f"${data['top51_diff']:<11.1f}M ${data['all_diff']:<11.1f}M {data['top51_diff_pct']:<9.1f}%")
    
    # Show biggest discrepancies
    print(f"\n🚨 BIGGEST DISCREPANCIES (vs Top-51 Cap)")
    print("=" * 60)
    
    for i, data in enumerate(comparison_data[:10], 1):
        status = "🔴 OVER" if data['top51_diff'] > 0 else "🟢 UNDER"
        print(f"{i:2d}. {data['nfl_abbr']:<4} ({data['pfl_team']:<20}) | ${data['top51_diff']:>8.1f}M | {status} | {data['top51_diff_pct']:>6.1f}% difference")
    
    # Show teams closest to real data
    print(f"\n✅ CLOSEST TO REAL DATA (vs Top-51 Cap)")
    print("=" * 60)
    
    comparison_data.sort(key=lambda x: abs(x['top51_diff_pct']))
    
    for i, data in enumerate(comparison_data[:10], 1):
        status = "🔴 OVER" if data['top51_diff'] > 0 else "🟢 UNDER"
        print(f"{i:2d}. {data['nfl_abbr']:<4} ({data['pfl_team']:<20}) | ${data['top51_diff']:>8.1f}M | {status} | {data['top51_diff_pct']:>6.1f}% difference")
    
    # Summary statistics
    print(f"\n📊 SUMMARY STATISTICS")
    print("=" * 60)
    
    total_real_top51 = sum(data['real_top51'] for data in comparison_data)
    total_pfl_apy = sum(data['pfl_apy'] for data in comparison_data)
    total_diff = total_pfl_apy - total_real_top51
    
    print(f"Total Real NFL Top-51 Cap: ${total_real_top51:.1f}M")
    print(f"Total PFL APY: ${total_pfl_apy:.1f}M")
    print(f"Total Difference: ${total_diff:.1f}M")
    print(f"Average Difference per Team: ${total_diff/len(comparison_data):.1f}M")
    
    # Save detailed comparison to CSV
    output_filename = "salary_comparison_results.csv"
    with open(output_filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['PFL_Team', 'NFL_Abbr', 'Real_Top51_Cap_M', 'Real_All_Cap_M', 'PFL_APY_M', 'Diff_Top51_M', 'Diff_All_M', 'Diff_Top51_Pct', 'Diff_All_Pct'])
        
        for data in comparison_data:
            writer.writerow([
                data['pfl_team'],
                data['nfl_abbr'],
                f"${data['real_top51']:.1f}M",
                f"${data['real_all']:.1f}M", 
                f"${data['pfl_apy']:.1f}M",
                f"${data['top51_diff']:.1f}M",
                f"${data['all_diff']:.1f}M",
                f"{data['top51_diff_pct']:.1f}%",
                f"{data['all_diff_pct']:.1f}%"
            ])
    
    print(f"\n💾 Detailed comparison saved to: {output_filename}")

if __name__ == "__main__":
    compare_salaries()
