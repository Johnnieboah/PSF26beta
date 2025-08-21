#!/usr/bin/env python3
"""
Team Salary Calculator
Calculates total salary spending for every team based on player contracts
"""

import csv
from collections import defaultdict
import locale

def calculate_team_salaries():
    """Calculate total salary spending for every team"""
    
    # Set locale for proper number formatting
    locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')
    
    # Dictionary to store team salary data
    team_salaries = defaultdict(lambda: {
        'total_apy': 0,
        'total_guaranteed': 0,
        'player_count': 0,
        'players': []
    })
    
    print("🏈 Loading team salary data from PFL2025DATA_ENHANCED.csv...")
    
    try:
        with open('PFL2025DATA_ENHANCED.csv', 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                team = row['Team']
                player_name = f"{row['firstName']} {row['lastName']}"
                position = row['Position']
                overall = row['overallRating']
                
                # Get contract data
                if 'contractAPY_M' in row and row['contractAPY_M'] != '':
                    apy = float(row['contractAPY_M'])
                    guaranteed = float(row['contractTotalGuaranteed_M']) if row['contractTotalGuaranteed_M'] != '' else 0
                    years = int(row['contractYears']) if row['contractYears'] != '' else 1
                    total_value = float(row['contractTotalValue_M']) if row['contractTotalValue_M'] != '' else apy * years
                    
                    # Add to team totals
                    team_salaries[team]['total_apy'] += apy
                    team_salaries[team]['total_guaranteed'] += guaranteed
                    team_salaries[team]['player_count'] += 1
                    
                    # Store player details
                    team_salaries[team]['players'].append({
                        'name': player_name,
                        'position': position,
                        'overall': overall,
                        'apy': apy,
                        'guaranteed': guaranteed,
                        'years': years,
                        'total_value': total_value
                    })
                else:
                    print(f"⚠️  Warning: {player_name} ({team}) has no contract data")
    
    except FileNotFoundError:
        print("❌ Error: PFL2025DATA_ENHANCED.csv not found!")
        return
    except Exception as e:
        print(f"❌ Error reading file: {e}")
        return
    
    # Sort teams by total APY (highest to lowest)
    sorted_teams = sorted(team_salaries.items(), 
                         key=lambda x: x[1]['total_apy'], 
                         reverse=True)
    
    # Display results
    print(f"\n🏆 TEAM SALARY RANKINGS (Total APY)")
    print("=" * 80)
    
    total_league_apy = 0
    total_league_guaranteed = 0
    total_league_players = 0
    
    for rank, (team, data) in enumerate(sorted_teams, 1):
        total_league_apy += data['total_apy']
        total_league_guaranteed += data['total_guaranteed']
        total_league_players += data['player_count']
        
        print(f"{rank:2d}. {team:20} | ${data['total_apy']:8.2f}M APY | {data['player_count']:3d} players | ${data['total_guaranteed']:8.2f}M guaranteed")
    
    print("=" * 80)
    print(f"LEAGUE TOTALS: ${total_league_apy:8.2f}M APY | {total_league_players:3d} players | ${total_league_guaranteed:8.2f}M guaranteed")
    
    # Show salary cap analysis
    nfl_salary_cap_2025 = 255.4  # Estimated 2025 NFL salary cap in millions
    print(f"\n💰 SALARY CAP ANALYSIS (2025 NFL Cap: ${nfl_salary_cap_2025}M)")
    print("=" * 80)
    
    for rank, (team, data) in enumerate(sorted_teams, 1):
        cap_percentage = (data['total_apy'] / nfl_salary_cap_2025) * 100
        status = "🟢 UNDER" if cap_percentage < 100 else "🔴 OVER"
        print(f"{rank:2d}. {team:20} | {cap_percentage:6.1f}% of cap | {status}")
    
    # Show top 10 highest paid players by team
    print(f"\n👑 TOP 10 HIGHEST PAID PLAYERS BY TEAM")
    print("=" * 80)
    
    for rank, (team, data) in enumerate(sorted_teams[:10], 1):
        print(f"\n{rank}. {team}")
        print("-" * 40)
        
        # Sort players by APY (highest to lowest)
        top_players = sorted(data['players'], key=lambda x: x['apy'], reverse=True)[:5]
        
        for i, player in enumerate(top_players, 1):
            print(f"   {i}. {player['name']:20} ({player['position']:2}) | ${player['apy']:6.2f}M APY | {player['overall']} OVR")
    
    # Save detailed results to CSV
    output_filename = "team_salary_breakdown.csv"
    with open(output_filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['Rank', 'Team', 'Total_APY_M', 'Total_Guaranteed_M', 'Player_Count', 'Cap_Percentage'])
        
        for rank, (team, data) in enumerate(sorted_teams, 1):
            cap_percentage = (data['total_apy'] / nfl_salary_cap_2025) * 100
            writer.writerow([rank, team, f"${data['total_apy']:.2f}M", f"${data['total_guaranteed']:.2f}M", data['player_count'], f"{cap_percentage:.1f}%"])
    
    print(f"\n💾 Detailed results saved to: {output_filename}")

if __name__ == "__main__":
    calculate_team_salaries()


